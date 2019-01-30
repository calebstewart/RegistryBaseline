<#
.SYNOPSIS
    Test the current running system against the given baseline object (returned
    from `Generate-RegistryBaseline`).

.DESCRIPTION
    Iterate through the given baseline and output a list of objects representing
    the differences between the running system and the baseline.

.PARAMETER Baseline
    An array of PSCustomObject items as returned by `Generate-RegistryBaseline`.
    You can save these to a file using `ConvertTo-Json | Out-File "baseline.json"`
    And then reuse it with the pipeline and `Get-Content | ConvertFrom-Json`.

.OUTPUTS
    When comparing a baseline, the result is a similar object, however each
    resultant object indicates a deviation from the baseline. Also, a new
    property is included named Baseline, which serves as the correct baseline
    value for that Key/Value pair and Value now indicates the current value of
    the key on this system.

.NOTES
    Name: Test-RegistryBaseline.ps1
    Author: Caleb Stewart
    DateCreated: 29JAN2019

.LINK
    https://github.com/Caleb1994/RegistryBaseline

.EXAMPLE
    PS C:\> Test-RegistryBaseline -Baseline (Get-Content C:\Persistence-Baseline.json | ConvertFrom-Json)

.EXAMPLE
    PS C:\> Get-Content C:\Persistence-Baseline-S-1-5.json | ConvertFrom-Json | Test-RegistryBaseline
#>
param(
    [Parameter(ValueFromPipeline=$true)][PSCustomObject[]]$Baseline
)

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

    ForEach( $ValueName in $key.GetValueNames() ) {
        if( $KeyInfo.Type -eq "match_only" -and -not $KeyInfo.Name.Contains($ValueName) ){
            $result += New-Object -TypeName PSObject -Property @{
                Key = $KeyInfo.Key;
                Name = $ValueName;
                Value = $key.GetValue($ValueName);
                Baseline = $null;
            }
        } elseif( ($KeyInfo.Value[$KeyInfo.Name.IndexOf($ValueName)]) -ne $key.GetValue($ValueName) ){
            $result += New-Object -TypeName PSObject -Property @{
                Key = $KeyInfo.Key;
                Name = $ValueName;
                Value = $key.GetValue($ValueName);
                Baseline = $KeyInfo.Value[$KeyInfo.Name.IndexOf($ValueName)];
            }
        }
    }

    # Increase iterator
    $iter += 1
}

return $result
