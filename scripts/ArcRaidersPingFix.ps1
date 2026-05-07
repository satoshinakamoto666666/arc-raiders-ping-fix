<#PSScriptInfo
.VERSION 1.0.0
.GUID 2c8ab69d-1b58-48da-a4c0-9b3358d7d6d7
.AUTHOR ARC Raiders Ping Fix contributors
.PROJECTURI https://github.com/satoshinakamoto666666/arc-raiders-ping-fix
.LICENSEURI https://github.com/satoshinakamoto666666/arc-raiders-ping-fix/blob/main/LICENSE
#>

<#
.SYNOPSIS
Diagnose and repair common Windows-side causes of high ping in ARC Raiders.

.DESCRIPTION
This menu-driven tool checks local latency, DNS, Windows Firewall, network adapter
settings, and ARC Raiders' local region option save. It can apply conservative
fixes with backups and prints a report that is safe to share.

.PARAMETER ReportOnly
Run diagnostics and exit without changing anything.

.PARAMETER ApplyRecommended
Apply the recommended local fixes without showing the interactive menu.

.PARAMETER RestoreLatestOptionsBackup
Restore the latest backup of EmbarkOptionSaveGame.sav created by this tool.

.PARAMETER Yes
Skip confirmation prompts for non-interactive use.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ReportOnly,
    [switch]$ApplyRecommended,
    [switch]$RestoreLatestOptionsBackup,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:GameName = 'ARC Raiders'
$Script:SteamAppId = '1808500'
$Script:LocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
$Script:SaveDir = Join-Path $Script:LocalAppData 'PioneerGame\Saved\SaveGames'
$Script:OptionsSave = Join-Path $Script:SaveDir 'EmbarkOptionSaveGame.sav'
$Script:ConfigDir = Join-Path $Script:LocalAppData 'PioneerGame\Saved\Config\WindowsClient'
$Script:ReportDir = Join-Path $env:TEMP 'ArcRaidersPingFix'
$Script:ReportPath = Join-Path $Script:ReportDir ("report_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Info {
    param([string]$Message)
    Write-Host "[info] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warn] $Message" -ForegroundColor Yellow
}

function Write-Good {
    param([string]$Message)
    Write-Host "[ ok ] $Message" -ForegroundColor Green
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-Action {
    param([string]$Prompt)
    if ($Yes) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return $answer -match '^(y|yes)$'
}

function Get-PrimaryAdapter {
    Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface } |
        Sort-Object -Property @{ Expression = { if ($_.Name -match 'Ethernet') { 0 } else { 1 } } }, InterfaceMetric |
        Select-Object -First 1
}

function Invoke-PingSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [int]$Count = 20
    )

    $output = & ping $Target -n $Count 2>&1
    $text = $output -join [Environment]::NewLine
    $loss = if ($text -match 'Lost = \d+ \((\d+)% loss\)') { [int]$Matches[1] } else { $null }
    $avg = if ($text -match 'Average = (\d+)ms') { [int]$Matches[1] } else { $null }
    $max = if ($text -match 'Maximum = (\d+)ms') { [int]$Matches[1] } else { $null }

    [pscustomobject]@{
        Target = $Target
        Count = $Count
        LossPercent = $loss
        AverageMs = $avg
        MaximumMs = $max
        Raw = $text
    }
}

function Get-ArcRaidersSteamPath {
    $roots = @()
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')

    if ($programFilesX86) {
        $roots += Join-Path -Path $programFilesX86 -ChildPath 'Steam\steamapps'
    }
    if ($programFiles) {
        $roots += Join-Path -Path $programFiles -ChildPath 'Steam\steamapps'
    }
    $roots = $roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($root in $roots) {
        $manifest = Join-Path $root "appmanifest_$Script:SteamAppId.acf"
        if (Test-Path -LiteralPath $manifest) {
            $content = Get-Content -LiteralPath $manifest -Raw
            if ($content -match '"installdir"\s+"([^"]+)"') {
                return Join-Path (Join-Path $root 'common') $Matches[1]
            }
        }
    }

    return $null
}

function Get-ArcRaidersExecutables {
    $root = Get-ArcRaidersSteamPath
    if (-not $root) { return @() }

    @(
        Join-Path $root 'PioneerGame\Binaries\Win64\PioneerGame.exe'
        Join-Path $root 'PioneerGame.exe'
        Join-Path $root 'start_protected_game.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ }
}

function Read-RegionValueFromSave {
    if (-not (Test-Path -LiteralPath $Script:OptionsSave)) { return $null }
    $bytes = [IO.File]::ReadAllBytes($Script:OptionsSave)
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    if ($text -match 'GameplayOption\.Online\.Region\W+([A-Za-z0-9_.-]+)') {
        return $Matches[1]
    }
    if ($text -match 'Online\.Region\.[A-Za-z0-9_.-]+') {
        return $Matches[0]
    }
    return $null
}

function Backup-OptionsSave {
    if (-not (Test-Path -LiteralPath $Script:OptionsSave)) {
        Write-Warn "Options save was not found: $Script:OptionsSave"
        return $null
    }

    $backup = "{0}.bak_{1}" -f $Script:OptionsSave, (Get-Date -Format 'yyyyMMdd_HHmmss')
    Copy-Item -LiteralPath $Script:OptionsSave -Destination $backup -Force
    Write-Good "Backed up options save to $backup"
    return $backup
}

function Reset-RegionOptionsSave {
    $processes = Get-Process | Where-Object { $_.ProcessName -match 'PioneerGame|start_protected_game' }
    if ($processes) {
        Write-Warn "$Script:GameName is running. Close the game before resetting the options save."
        if (Confirm-Action 'Stop ARC Raiders now?') {
            $processes | Stop-Process -Force
            Start-Sleep -Seconds 3
        } else {
            return
        }
    }

    $backup = Backup-OptionsSave
    if ($backup) {
        Remove-Item -LiteralPath $Script:OptionsSave -Force
        Write-Good 'Removed stale options save. The game will recreate it with default/auto region settings.'
    }
}

function Restore-LatestOptionsBackup {
    $latest = Get-ChildItem -LiteralPath $Script:SaveDir -Filter 'EmbarkOptionSaveGame.sav.bak_*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        Write-Warn 'No options-save backup created by this tool was found.'
        return
    }

    Copy-Item -LiteralPath $latest.FullName -Destination $Script:OptionsSave -Force
    Write-Good "Restored $($latest.FullName)"
}

function Set-CloudflareDns {
    $adapter = Get-PrimaryAdapter
    if (-not $adapter) {
        Write-Warn 'No active physical network adapter was found.'
        return
    }

    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @('1.1.1.1', '1.0.0.1')
    Clear-DnsClientCache
    & ipconfig /flushdns | Out-Null
    Write-Good "Set DNS on $($adapter.Name) to Cloudflare and flushed DNS cache."
}

function Add-ArcRaidersFirewallRules {
    $executables = Get-ArcRaidersExecutables
    if (-not $executables) {
        Write-Warn 'ARC Raiders executables were not found in the default Steam library.'
        return
    }

    foreach ($exe in $executables) {
        $displayName = "ARC Raiders - $(Split-Path $exe -Leaf) inbound"
        $existing = Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue
        if ($existing) {
            Set-NetFirewallRule -DisplayName $displayName -Enabled True -Action Allow -Profile Any
        } else {
            New-NetFirewallRule -DisplayName $displayName -Direction Inbound -Program $exe -Action Allow -Profile Any | Out-Null
        }
        Write-Good "Allowed inbound firewall rule for $exe"
    }
}

function Disable-InterruptModeration {
    $adapter = Get-PrimaryAdapter
    if (-not $adapter) {
        Write-Warn 'No active physical network adapter was found.'
        return
    }

    $property = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword '*InterruptModeration' -ErrorAction SilentlyContinue
    if (-not $property) {
        Write-Warn "Adapter $($adapter.Name) does not expose Interrupt Moderation."
        return
    }

    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword '*InterruptModeration' -RegistryValue 0
    Write-Good "Disabled Interrupt Moderation on $($adapter.Name)."
}

function Reset-Winsock {
    & netsh winsock reset | Out-Null
    Write-Good 'Reset Winsock. Restart Windows before testing the game.'
}

function Invoke-Diagnostics {
    New-Item -ItemType Directory -Path $Script:ReportDir -Force | Out-Null
    $lines = [System.Collections.Generic.List[string]]::new()
    $adapter = Get-PrimaryAdapter
    $region = Read-RegionValueFromSave
    $dns = if ($adapter) { Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue } else { $null }

    $lines.Add("ARC Raiders Ping Fix report")
    $lines.Add("Generated: $(Get-Date -Format o)")
    $lines.Add("")
    $lines.Add("Admin: $(Test-IsAdmin)")
    $lines.Add("Adapter: $(if ($adapter) { "$($adapter.Name) / $($adapter.InterfaceDescription) / $($adapter.LinkSpeed)" } else { 'not found' })")
    $lines.Add("DNS: $(if ($dns) { ($dns.ServerAddresses -join ', ') } else { 'not found' })")
    $lines.Add("Options save: $Script:OptionsSave")
    $lines.Add("Saved region: $(if ($region) { $region } else { 'not set or not found' })")
    $lines.Add("Game install: $(if (Get-ArcRaidersSteamPath) { Get-ArcRaidersSteamPath } else { 'not found' })")
    $lines.Add("")

    $targets = @('192.168.0.1', '1.1.1.1', '8.8.8.8')
    foreach ($target in $targets) {
        $summary = Invoke-PingSummary -Target $target -Count 10
        $lines.Add("Ping $target - loss=$($summary.LossPercent)% avg=$($summary.AverageMs)ms max=$($summary.MaximumMs)ms")
    }

    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($region -and $region -match 'Europe') {
        $warnings.Add('Saved region is Europe. If you are not near Europe, reset the options save or choose a closer in-game region.')
    }
    if ($dns -and ($dns.ServerAddresses -contains '192.168.0.1')) {
        $warnings.Add('DNS is using the router. This is usually fine, but switching to a public resolver can avoid stale router DNS cache.')
    }

    $lines.Add("")
    $lines.Add("Findings:")
    if ($warnings.Count -eq 0) {
        $lines.Add("- No obvious local misconfiguration found.")
    } else {
        foreach ($warning in $warnings) {
            $lines.Add("- $warning")
        }
    }

    Set-Content -LiteralPath $Script:ReportPath -Value $lines -Encoding UTF8
    $lines | ForEach-Object { Write-Host $_ }
    Write-Good "Report saved to $Script:ReportPath"
}

function Invoke-RecommendedFixes {
    if (-not (Test-IsAdmin)) {
        throw 'Run PowerShell as Administrator to apply DNS, firewall, adapter, and Winsock changes.'
    }

    Set-CloudflareDns
    Add-ArcRaidersFirewallRules
    Disable-InterruptModeration
    $region = Read-RegionValueFromSave
    if ($region -and $region -match 'Europe') {
        Reset-RegionOptionsSave
    } else {
        Write-Info 'No Europe region value found in the current options save.'
    }
    Reset-Winsock
}

function Show-Menu {
    while ($true) {
        Write-Host ''
        Write-Host 'ARC Raiders Ping Fix' -ForegroundColor White
        Write-Host '1. Run diagnostics only'
        Write-Host '2. Apply recommended fixes'
        Write-Host '3. Reset ARC Raiders region/options save'
        Write-Host '4. Set DNS to Cloudflare and flush cache'
        Write-Host '5. Add ARC Raiders firewall rules'
        Write-Host '6. Disable Ethernet Interrupt Moderation'
        Write-Host '7. Reset Winsock'
        Write-Host '8. Restore latest options-save backup'
        Write-Host '9. Launch ARC Raiders through Steam'
        Write-Host '0. Exit'
        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' { Invoke-Diagnostics }
            '2' { if (Confirm-Action 'Apply all recommended local fixes?') { Invoke-RecommendedFixes } }
            '3' { if (Confirm-Action 'Back up and remove the ARC Raiders options save?') { Reset-RegionOptionsSave } }
            '4' { if (Confirm-Action 'Set DNS to Cloudflare on the active adapter?') { Set-CloudflareDns } }
            '5' { Add-ArcRaidersFirewallRules }
            '6' { if (Confirm-Action 'Disable Interrupt Moderation on the active adapter?') { Disable-InterruptModeration } }
            '7' { if (Confirm-Action 'Reset Winsock? A reboot is required afterward.') { Reset-Winsock } }
            '8' { if (Confirm-Action 'Restore the latest options backup?') { Restore-LatestOptionsBackup } }
            '9' { Start-Process "steam://rungameid/$Script:SteamAppId" }
            '0' { return }
            default { Write-Warn 'Unknown option.' }
        }
    }
}

try {
    if ($RestoreLatestOptionsBackup) {
        Restore-LatestOptionsBackup
    } elseif ($ReportOnly) {
        Invoke-Diagnostics
    } elseif ($ApplyRecommended) {
        Invoke-RecommendedFixes
    } else {
        Show-Menu
    }
} catch {
    Write-Error $_
    exit 1
}
