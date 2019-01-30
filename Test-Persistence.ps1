<#
.SYNOPSIS
    Test for common persistence methods in the Windows Registry.

.DESCRIPTION
    Test-Persistence can first generate a baseline of the current registry,
    and then can compare the current registry with an old baseline, reporting
    all discrepancies.

    This script will check the following persistence locations:
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

.PARAMETER BaselineKeys
    A hashtable containing items whose keys are the path to a registry key and
    whose value is an array indicating values of interest within the registry
    key. Is the value is an empty array, all values are considered important.
    This parameter is only used when taking a basline to know what to log.

.PARAMETER TakeBaseline
    Tells the script to create a baseline based on this machine instead of
    comparing a given baseline.

.PARAMETER Baseline
    An array of PSCustomObject items as returned by `-TakeBaseline`. 

.PARAMETER Sid
    The SID you would like to search (for user specific registry keys). This can
    contain wildcards, and defaults to all SIDs. This is only relevant while
    taking a baseline.

.OUTPUTS
    When generating a baseline, an array of PSCustomObjects is returned
    indicating keys of interest and their associated values. Each object
    has Key, Name, and Value properties indicating the Key path, value name
    and value of interest.

    When comparing a baseline, the result is a similar object, however each
    resultant object indicates a deviation from the baseline. Also, a new
    property is included named Baseline, which serves as the correct baseline
    value for that Key/Value pair and Value now indicates the current value of
    the key on this system.

.NOTES
    Name: Test-Persistence.ps1
    Author: Caleb Stewart
    DateCreated: 29JAN2019

.LINK
    https://github.com/Caleb1994/Test-Persistence

.EXAMPLE
    PS C:\> Test-Persistence -TakeBaseline | ConvertTo-Json | Out-File C:\Persistence-Baseline.json

.EXAMPLE
    PS C:\> Test-Persistence -Baseline (Get-Content C:\Persistence-Baseline.json | ConvertFrom-Json)

.EXAMPLE
    PS C:\> Test-Persistence -TakeBaseline -Sid S-1-5* | ConvertTo-Json | Out-File C:\Persistence-Baseline-S-1-5.json

.EXAMPLE
    PS C:\> Get-Content C:\Persistence-Baseline-S-1-5.json | ConvertFrom-Json | Test-Persistence
#>
param(
    [HashTable]$BaselineKeys = @{
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
    [switch]$TakeBaseline,
    [Parameter(ValueFromPipeline=$true)][PSCustomObject[]]$Baseline,
    [string]$Sid = "*"
)

if( $TakeBaseline) {

    # We are taking a baseline. Make sure this is cleared
    $Baseline = @()
    
    # Iterate through each key
    ForEach( $KeyName in $BaselineKeys.Keys ) {
        # Display progress
        # Notify of progress
        Write-Progress -Activity "Test-Persistence - Generating Baseline" `
            -Status "Evaluating $KeyName" `
            -PercentComplete (([float]$iter/$BaselineKeys.Count)*100.0)

        # Ensure the registry key exists
        if( -not (Test-Path ("Registry::$KeyName" -f $Sid)) ){
            continue
        }

        # Iterate over all keys found (could have wild cards for user or Control Sets)
        ForEach( $key in (Get-Item ("Registry::$KeyName" -f $Sid)) ){
            if( $BaselineKeys[$KeyName].Count -eq 0 ){
                # Baseline all values in this key
                ForEach( $ValueName in $key.GetValueNames() ){
                    $Baseline += New-Object -TypeName PSobject -Property @{
                        Key = $key.PSPath;
                        Name = $ValueName;
                        Value = $key.GetValue($ValueName);
                    }
                }
            } else {
                # Baseline only specified values in this key
                ForEach( $ValueName in $BaselineKeys[$KeyName] ){
                    if( $key.GetValueNames().Contains($ValueName) ){
                        $Baseline += New-Object -TypeName PSObject -Property @{
                            Key = $key.PSPath;
                            Name = $ValueName;
                            Value = $key.GetValue($ValueName);
                        }
                    }
                }
            }

        }

        # Increment iter
        $iter += 1
    }

    return $Baseline
} else {
    $result = @()
    $iter = 0

    ForEach( $KeyInfo in $Baseline ) {
        # Notify of progress
        Write-Progress -Activity "Test-Persistence - Comparing Baseline" `
            -Status "Testing $($KeyInfo.Key)\$($KeyInfo.Name)" `
            -PercentComplete (([float]$iter/$Baseline.Count)*100.0)

        # Ensure the key exists
        if( -not (Test-Path $KeyInfo.Key) ){
            $result += New-Object -TypeName PSObject -Property @{
                Key = $KeyInfo.Name;
                Name = $null;
                Value = $null;
            }
            continue
        }

        # Grab the current values
        $key = Get-Item $KeyInfo.Key

        # Check that the values are correct
        if( $key.GetValue($KeyInfo.Name) -ne $KeyInfo.Value ){
            $result += New-Object -TypeName PSobject -Property @{
                Key = $KeyInfo.Key;
                Name = $KeyInfo.Name;
                Value = $key.GetValue($KeyInfo.Name);
                Baseline = $KeyInfo.Value;
            }
        }

        # Increase iterator
        $iter += 1
    }

    return $result
}
