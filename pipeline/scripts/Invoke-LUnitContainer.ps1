[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Setup', 'Test')]
    [string]$Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($env:LV_YEAR -notmatch '^\d{4}$' -or [int]$env:LV_YEAR -lt 2026) {
    throw 'LV_YEAR must identify LabVIEW 2026 or later for headless execution.'
}

$lvRoot = "C:\Program Files\National Instruments\LabVIEW $env:LV_YEAR"
$labview = Join-Path $lvRoot 'LabVIEW.exe'
$labviewCli = 'C:\Program Files (x86)\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'
$logRoot = 'C:\unit-test-results'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

foreach ($path in @($labview, $labviewCli)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required LabVIEW executable not found: $path"
    }
}

if ($Mode -eq 'Setup') {
    $env:VIPM_NONINTERACTIVE = '1'
    $env:VIPM_TIMEOUT = '900'
    $env:NO_COLOR = '1'
    foreach ($name in @('VIPM_SERIAL_NUMBER', 'VIPM_FULL_NAME', 'VIPM_EMAIL')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw "Required VIPM Pro activation environment variable is missing: $name"
        }
    }

    $vipm = 'C:\Program Files\JKI\VI Package Manager\support\vipm.exe'
    if (-not (Test-Path -LiteralPath $vipm -PathType Leaf)) {
        $installer = Join-Path $env:TEMP 'vipm-setup.exe'
        try {
            Invoke-WebRequest -Uri 'https://packages.jki.net/vipm/preview/vipm-setup-latest-preview.exe' `
                -OutFile $installer -UseBasicParsing
            if ((Get-AuthenticodeSignature -FilePath $installer).Status -ne 'Valid') {
                throw 'The VIPM installer does not have a valid Authenticode signature.'
            }
            $process = Start-Process -FilePath $installer -ArgumentList '/quiet', '/norestart' -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                throw "VIPM installation failed with exit code $($process.ExitCode)."
            }
        }
        finally {
            if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
        }
    }
    if (-not (Test-Path -LiteralPath $vipm -PathType Leaf)) {
        throw "VIPM CLI was not installed at $vipm"
    }

    # Do not publish activation output or include credentials in a transcript.
    $activationOutput = & $vipm activate --serial-number $env:VIPM_SERIAL_NUMBER `
        --name $env:VIPM_FULL_NAME --email $env:VIPM_EMAIL 2>&1
    $activationExitCode = $LASTEXITCODE
    Remove-Variable activationOutput
    if ($activationExitCode -ne 0) {
        throw "VIPM Pro activation failed with exit code $activationExitCode. Check the configured credentials and entitlement."
    }
    foreach ($name in @('VIPM_SERIAL_NUMBER', 'VIPM_FULL_NAME', 'VIPM_EMAIL')) {
        [Environment]::SetEnvironmentVariable($name, $null)
    }

    & $vipm version
    if ($LASTEXITCODE -ne 0) { throw 'Failed to query the VIPM version.' }
    & $vipm refresh
    if ($LASTEXITCODE -ne 0) { throw 'Failed to refresh VIPM package sources.' }

    $labviewProcess = Start-Process -FilePath $labview -ArgumentList '--headless' -PassThru
    $deadline = (Get-Date).AddMinutes(3)
    do {
        if ($labviewProcess.HasExited) { throw 'Headless LabVIEW exited before package installation.' }
        $ready = Test-NetConnection -ComputerName localhost -Port 3363 `
            -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $ready) { Start-Sleep -Seconds 2 }
    } until ($ready -or (Get-Date) -ge $deadline)
    if (-not $ready) { throw 'Headless LabVIEW did not open VI Server port 3363 within three minutes.' }

    & $vipm install -y astemes_lib_lunit astemes_lib_lunit_cli `
        --labview-version $env:LV_YEAR --labview-bitness 64 2>&1 |
        Tee-Object -FilePath (Join-Path $logRoot 'dependency-install.log')
    if ($LASTEXITCODE -ne 0) { throw 'Failed to install LUnit and its native CLI package.' }
    & $vipm list --installed --labview-version $env:LV_YEAR --labview-bitness 64 2>&1 |
        Tee-Object -FilePath (Join-Path $logRoot 'installed-packages.log')
    if ($LASTEXITCODE -ne 0) { throw 'Failed to list the installed packages.' }

    $operation = Join-Path $lvRoot 'vi.lib\Astemes\LUnit CLI\LUnitCLI'
    if (-not (Test-Path -LiteralPath $operation -PathType Container)) {
        throw "The native LUnit CLI operation was not installed at $operation"
    }
    return
}

$project = 'C:\actor-framework\Core\Actor Framework Core.lvproj'
$testRoot = 'C:\actor-framework\Test\Unit Tests'
foreach ($path in @($project, $testRoot)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Migrated LUnit project or test suite is missing: $path"
    }
}

Start-Transcript -Path (Join-Path $logRoot 'lunit-execution.log') -Force | Out-Null
try {
    Set-Location 'C:\actor-framework'
    & $labviewCli -OperationName LUnit `
        -LabVIEWPath $labview `
        -AdditionalOperationDirectory (Join-Path $lvRoot 'vi.lib\Astemes\LUnit CLI') `
        -Path $project `
        -ReportPath (Join-Path $logRoot 'lunit.xml') `
        -LogToConsole TRUE `
        -Headless
    if ($LASTEXITCODE -ne 0) {
        throw "LabVIEW CLI LUnit failed with exit code $LASTEXITCODE."
    }
}
finally {
    Stop-Transcript | Out-Null
}
