# Contributing

Thanks for improving ARC Raiders Ping Fix.

## Development Rules

- Keep all changes reversible where possible.
- Back up user files before modifying or removing them.
- Do not add telemetry.
- Do not collect tokens, Steam credentials, or personal information.
- Prefer diagnostics before fixes.
- Keep the script compatible with Windows PowerShell 5.1.

## Testing

Run the parser check:

```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile(
  ".\scripts\ArcRaidersPingFix.ps1",
  [ref]$null,
  [ref]$null
)
```

Run diagnostics:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -ReportOnly
```
