# Test-Persistence - Create Persistence Baseline and Compare Baselines with Running Systems

This script can create and compare registry baselines. By default, the registry keys inspected are common persistence locations (such as `Run` and `RunOnce` keys). You should first take a baseline of a known-good system, and then use this script to compare the baseline output with another running system.

## Creating a Baseline Snapshot

The `-TakeBaseline` switch is used to create a new baseline. The registry keys that are checked are set by the `-BaselineKeys` option, which by default is set to a list of common persistence locations. You may also specify a `-Sid` parameter in order to only scan user keys for a specific user (or a wild-card user). The `Sid` value is a wildcard by default in order to inventory all user hives.

```powershell
PS C:\> Test-Persistence.ps1 -TakeBaseline | ConvertTo-Json | Out-File "baseline.json"

PS C:\> 
```

## Creating a Baseline with specific SIDs

```powershell
PS C:\> Test-Persistence -TakeBaseline -Sid "S-1-5*" | ConvertTo-Json | Out-File "baseline.json"

PS C:\>
```

## Compare Baseline with Different Host

```powershell
PS C:\> Get-Content "baseline.json" | ConvertFrom-Json | Test-Persistance

Key                                                                                                  Name        Baseline Value                
---                                                                                                  ----        -------- -----                
Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run This is Bad          %APPDATA%\malware.exe
```
