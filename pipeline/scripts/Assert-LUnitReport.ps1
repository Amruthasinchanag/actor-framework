[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [ValidateRange(1, 2147483647)]
    [int]$MinimumTests = 13
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "LUnit did not produce a JUnit report at $ReportPath"
}

$settings = New-Object System.Xml.XmlReaderSettings
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$reader = [System.Xml.XmlReader]::Create($ReportPath, $settings)
try {
    $report = New-Object System.Xml.XmlDocument
    $report.XmlResolver = $null
    $report.Load($reader)
}
finally {
    $reader.Dispose()
}

if ($report.DocumentElement.Name -notin @('testsuite', 'testsuites')) {
    throw 'LUnit report must have a testsuite or testsuites root element.'
}

$cases = @($report.SelectNodes('//testcase'))
$failures = @($report.SelectNodes('//failure | //error'))
$skipped = @($report.SelectNodes('//testcase[skipped]'))
$executed = $cases.Count - $skipped.Count

if ($failures.Count -gt 0) {
    throw "LUnit reported $($failures.Count) failure/error entries. Inspect $ReportPath"
}
foreach ($suite in $report.SelectNodes('//testsuite | /testsuites')) {
    foreach ($attribute in @('failures', 'errors')) {
        $value = $suite.GetAttribute($attribute)
        if ($value -and $value -notmatch '^0+$') {
            throw "LUnit reported a nonzero or invalid $attribute count: $value"
        }
    }
}
if ($executed -lt $MinimumTests) {
    throw "LUnit executed $executed tests; expected at least $MinimumTests. Discovered $($cases.Count), skipped $($skipped.Count)."
}

[pscustomobject]@{
    Discovered = $cases.Count
    Executed = $executed
    Skipped = $skipped.Count
}
