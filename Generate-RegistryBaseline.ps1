<#
.SYNOPSIS
    Create windows registry baseline of specified keys (normally used for
    common persistence method baselining on known-good hosts).

.DESCRIPTION
    Generate-RegistryBaseline will create a list of objects which act as a
    baseline for the Windows Registry to be used with Test-RegistryBaseline.
    By default, it will baseline the following common malware persistence
    registry locations:
        - Run/RunOnce keys
        - BootExecute key
        - UserInit key
        - Notify event handlers
        - Winlogon Shell and Boot Shell keys
        - Startup Keys
        - Services
        - Browser Help Objects
        - AppInit_DLLs
        - File Associations
        - KnownDLLs

.PARAMETER InterestingKeys
    A hashtable containing items whose keys are the path to a registry key and
    whose value is an array indicating values of interest within the registry
    key. If the value is an empty array, all values are considered important,
    and any additional values added will trigger as a modification of interest.

.PARAMETER Sid
    The SID you would like to search (for user specific registry keys). This can
    contain wildcards, and defaults to all SIDs.

.OUTPUTS
    When generating a baseline, an array of PSCustomObjects is returned
    indicating keys of interest and their associated values. Each object
    has Key, Name, and Value properties indicating the Key path, value name
    and value of interest.

.NOTES
    Name: Generate-RegistryBaseline.ps1
    Author: Caleb Stewart
    DateCreated: 29JAN2019

.LINK
    https://github.com/Caleb1994/RegistryBaselining

.EXAMPLE
    PS C:\> Generate-RegistryBaseline | ConvertTo-Json | Out-File C:\Persistence-Baseline.json

.EXAMPLE
    PS C:\> Generate-RegistryBaseline -Sid S-1-5* | ConvertTo-Json | Out-File C:\Persistence-Baseline-S-1-5.json

#>
param(
    [HashTable]$InterestingKeys = @{
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" = @();
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" = @();
        "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" = @();
        "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet*\Control\Session Manager" = @( "BootExecute" );
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" = @( "Userinit", "Shell" );
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Notify" = @();
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\system.ini\boot" = @( "Shell" );
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" = @();
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" = @();
        "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services" = @();
        "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run\Services\Once" = @();
        "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run\Services" = @();
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" = @( "Browser Helper Objects" );
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" = @( "AppInit_DLLs" );
        "HKEY_LOCAL_MACHINE\Software\Classes" = @();
        "HKEY_CLASSES_ROOT" = @();
        "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs" = @();
        "HKEY_USERS\{0}\Software\Microsoft\Windows\CurrentVersion\Run" = @();
        "HKEY_USERS\{0}\Software\Microsoft\Windows\CurrentVersion\RunOnce" = @();
        
    },
    [string]$Sid = "*"
)

# Initialize Baseline Array
$Baseline = @()
    
# Iterate through each key
ForEach( $KeyName in $InterestingKeys.Keys ) {
    # Display progress
    Write-Progress -Activity "Generate-RegistryBaseline" `
        -Status "Evaluating $KeyName" `
        -PercentComplete (([float]$iter/$InterestingKeys.Count)*100.0)

    # Ensure the registry key exists
    if( -not (Test-Path ("Registry::$KeyName" -f $Sid)) ){
        continue
    }

    # Iterate over all keys found (could have wild cards for user or Control Sets)
    ForEach( $key in (Get-Item ("Registry::$KeyName" -f $Sid)) ){
        if( $InterestingKeys[$KeyName].Count -eq 0 ){
            # Baseline all values in this key (and ensure no new keys are added)
            $Baseline += New-Object -TypeName PSobject -Property @{
                Key = $key.PSPath;
                Type = "match_only";
                Name = @( $key.GetValueNames() );
                Value = @( $key.GetValueNames() | % { $key.GetValue($_) } );
            }
        } elseif( ($InterestingKeys[$KeyName] | Where-Object { $key.GetValueNames().Contains($InterestingKeys[$KeyName]) }).Count > 0 ) {
            # Baseline only specified values in this key
            $Baseline += New-Object -TypeName PSObject -Property @{
                Key = $key.PSPath;
                Type = "match";
                Values = $key
                Name = @( $InterestingKeys[$KeyName] | Where-Object { $key.GetValueNames().Contains($InterestingKeys[$KeyName]) } );
                Value = @( $InterestingKeys[$KeyName] | Where-Object { $key.GetValueNames().Contains($InterestingKeys[$KeyName]) } | % { $key.GetValue($_) } );
            }
        }

    }

    # Increment iter
    $iter += 1
}

return $Baseline
