# Troubleshooting

## My speed test is 1 ms but ARC Raiders ping is high

Speed tests usually hit a nearby ISP or CDN server. ARC Raiders match ping depends on the route to the selected game server, the selected region, server load, and packet loss.

Run:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -ReportOnly
```

If the report shows `Online.Region.Europe` and you are not near Europe, run menu option `3` or the recommended fix option.

## PowerShell says scripts are disabled

Use a process-only execution policy:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This affects only the current PowerShell window.

## The script says admin is required

Open PowerShell as Administrator. Diagnostics can run as a normal user, but DNS, firewall, adapter, and Winsock changes require admin rights.

## Ping is still high after the fixes

If diagnostics show low latency and 0% packet loss to gateway, Cloudflare, and Google, the remaining issue is probably outside the local PC:

- ARC Raiders matched you to a far region.
- The closest game server is overloaded.
- Your ISP has poor routing to that game server.
- A VPN or accelerator is changing the route.
- The game currently has a regional matchmaking issue.

In that case, collect the report and include the in-game ping, country/region, ISP, and whether a VPN is active when reporting the issue.

## How do I undo the options reset?

Use menu option `8`, or run:

```powershell
.\scripts\ArcRaidersPingFix.ps1 -RestoreLatestOptionsBackup -Yes
```

## How do I undo Cloudflare DNS?

Open Windows network adapter DNS settings and return to automatic DNS, or run this in Administrator PowerShell after replacing `Ethernet` with your adapter name:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses
```

## How do I re-enable Interrupt Moderation?

Run this in Administrator PowerShell after replacing `Ethernet` with your adapter name:

```powershell
Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*InterruptModeration" -RegistryValue 1
```
