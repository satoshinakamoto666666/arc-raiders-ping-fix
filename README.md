# ARC Raiders Ping Fix

Menu-driven Windows diagnostics and repair script for common local causes of high ping in ARC Raiders.

The tool checks your active network adapter, DNS, packet loss, Windows Firewall rules, Realtek adapter latency settings, Winsock state, and ARC Raiders' local options save. It can back up and reset a stale saved region value, such as `Online.Region.Europe`, that may cause off-region matchmaking.

## What It Fixes

- ARC Raiders saved to the wrong online region
- Stale router DNS or Windows DNS cache
- Missing inbound Windows Firewall rules for game executables
- Realtek Ethernet Interrupt Moderation latency
- Corrupt or stale Winsock catalog state
- Basic packet loss and jitter visibility

## What It Does Not Fix

- Game server outages or overloaded matchmaking
- ISP routing problems outside your home network
- Missing ARC Raiders server regions in your area
- Router-level NAT, UPnP, or port forwarding settings
- VPN routing problems unless you disable the VPN yourself

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or newer
- ARC Raiders installed through Steam
- Administrator PowerShell for applying fixes

Diagnostics can run without administrator rights. Fixes that change DNS, firewall, adapter settings, or Winsock require administrator rights.

## Quick Start

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\ArcRaidersPingFix.ps1
```

Choose:

- `1` to run diagnostics only
- `2` to apply the recommended local fixes
- `3` to reset only the ARC Raiders region/options save
- `8` to restore the latest options-save backup

Restart Windows after running option `2` or option `7`, because Winsock reset requires a reboot.

## Non-Interactive Usage

Run diagnostics and write a shareable report:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -ReportOnly
```

Apply all recommended fixes without menu prompts:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -ApplyRecommended -Yes
```

Restore the latest options-save backup:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -RestoreLatestOptionsBackup -Yes
```

## Safety

The script backs up `EmbarkOptionSaveGame.sav` before removing it. Backups are stored next to the original file with a `.bak_yyyyMMdd_HHmmss` suffix.

The options save contains gameplay and UI preferences. Resetting it should not remove keybindings, because ARC Raiders stores keybindings separately, but you may need to re-check in-game preferences afterward.

The script does not:

- Modify game binaries
- Modify Steam files
- Delete backups
- Read or transmit tokens
- Contact any third-party service except normal ping targets when diagnostics are run

## Troubleshooting

If PowerShell blocks the script, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

If ARC Raiders recreates the wrong region, open the game settings and choose the closest available region or automatic region selection.

If diagnostics show low ping to `1.1.1.1` and `8.8.8.8` but ARC Raiders still has high match ping, the issue is probably matchmaking region, game server load, or ISP routing to that specific game server.

## Contributing

Pull requests are welcome. Keep changes conservative: this tool should prefer diagnostics, backups, and reversible changes over aggressive network tweaking.

## License

MIT. See [LICENSE](LICENSE).
