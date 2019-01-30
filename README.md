# Registry Baseline - Create Registry Baselines and Compare them to Running Hosts

These scripts can create and compare registry baselines. By default, the registry keys inspected are common persistence locations (such as `Run` and `RunOnce` keys). You should first take a baseline of a known-good system using `Generate-RegistryBaseline`, and then use the `Test-RegistryBaseline` script to compare the baseline output with another running system.

## Creating a Baseline Snapshot (on Known-Good Host)

The `-TakeBaseline` switch is used to create a new baseline. The registry keys that are checked are set by the `-BaselineKeys` option, which by default is set to a list of common persistence locations. You may also specify a `-Sid` parameter in order to only scan user keys for a specific user (or a wild-card user). The `Sid` value is a wildcard by default in order to inventory all user hives.

```powershell
PS C:\> Generate-RegistryBaseline | ConvertTo-Json | Out-File "baseline.json"

PS C:\> 
```

## Creating a Baseline with specific SIDs (on Known-Good host)

```powershell
PS C:\> Generate-RegistryBaseline -Sid "S-1-5*" | ConvertTo-Json | Out-File "baseline.json"

PS C:\>
```

## Compare Baseline with Different Host (on suspicious, possibly infected host)

```powershell
PS C:\> Get-Content "baseline.json" | ConvertFrom-Json | Test-RegistryBaseline

Key                                                                                                  Name        Baseline Value                
---                                                                                                  ----        -------- -----                
Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run This is Bad          %APPDATA%\malware.exe
```
