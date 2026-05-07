# Usage Guide

## Recommended Flow

1. Close ARC Raiders.
2. Open PowerShell as Administrator.
3. Start the tool:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\ArcRaidersPingFix.ps1
```

4. Choose `1` first to run diagnostics.
5. Choose `2` to apply recommended fixes.
6. Restart Windows.
7. Launch ARC Raiders and test matchmaking ping.

## Menu Options

### 1. Run diagnostics only

Creates a local report in your temp folder and prints:

- Active network adapter
- DNS servers
- Saved ARC Raiders online region
- Steam install path
- Ping loss and latency to gateway, Cloudflare, and Google

### 2. Apply recommended fixes

Runs the conservative repair bundle:

- Sets DNS to Cloudflare
- Flushes Windows DNS cache
- Adds inbound Windows Firewall allow rules for ARC Raiders executables
- Disables Interrupt Moderation on the active adapter when supported
- Resets stale ARC Raiders region options if a Europe value is found
- Resets Winsock

Restart Windows after using this option.

### 3. Reset ARC Raiders region/options save

Backs up and removes:

```text
%LOCALAPPDATA%\PioneerGame\Saved\SaveGames\EmbarkOptionSaveGame.sav
```

ARC Raiders recreates this file on launch. Use this when diagnostics show a saved region far away from you.

### 4. Set DNS to Cloudflare and flush cache

Changes the active physical adapter to:

```text
1.1.1.1
1.0.0.1
```

### 5. Add ARC Raiders firewall rules

Adds inbound allow rules for the Steam install's main game executables.

### 6. Disable Ethernet Interrupt Moderation

Disables the adapter feature when Windows exposes it. This can reduce latency spikes on some Realtek adapters.

### 7. Reset Winsock

Repairs the Windows socket catalog. Restart Windows afterward.

### 8. Restore latest options-save backup

Restores the newest `.bak_yyyyMMdd_HHmmss` backup created by this tool.

### 9. Launch ARC Raiders through Steam

Runs:

```text
steam://rungameid/1808500
```

## Report Location

Reports are saved to:

```text
%TEMP%\ArcRaidersPingFix
```

Reports are intended to be safe to share, but review them before posting publicly.
