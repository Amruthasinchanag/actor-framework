$validator = Join-Path $PSScriptRoot '..\scripts\Assert-LUnitReport.ps1'

Describe 'LUnit JUnit report validation' {
    It 'accepts the full migrated suite' {
        $path = Join-Path $TestDrive 'passing.xml'
        $cases = 1..13 | ForEach-Object { "<testcase name='test$_'/>" }
        Set-Content $path "<testsuites><testsuite tests='13' failures='0' errors='0'>$cases</testsuite></testsuites>"
        $result = & $validator -ReportPath $path
        $result.Executed | Should Be 13
        $result.Skipped | Should Be 0
    }

    It 'accepts a single testsuite root' {
        $path = Join-Path $TestDrive 'single.xml'
        Set-Content $path '<testsuite><testcase name="test"/></testsuite>'
        (& $validator -ReportPath $path -MinimumTests 1).Executed | Should Be 1
    }

    It 'rejects a missing report' {
        { & $validator -ReportPath (Join-Path $TestDrive 'missing.xml') } | Should Throw
    }

    It 'rejects malformed XML' {
        $path = Join-Path $TestDrive 'malformed.xml'
        Set-Content $path '<testsuite>'
        { & $validator -ReportPath $path } | Should Throw
    }

    It 'rejects an unexpected root' {
        $path = Join-Path $TestDrive 'wrong-root.xml'
        Set-Content $path '<report><testcase/></report>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }

    It 'rejects zero discovered tests' {
        $path = Join-Path $TestDrive 'empty.xml'
        Set-Content $path '<testsuite tests="0"/>'
        { & $validator -ReportPath $path } | Should Throw
    }

    It 'checks actual cases rather than trusting the declared count' {
        $path = Join-Path $TestDrive 'too-few.xml'
        Set-Content $path '<testsuite tests="13"><testcase/></testsuite>'
        { & $validator -ReportPath $path } | Should Throw
    }

    It 'does not count skipped cases as executed tests' {
        $path = Join-Path $TestDrive 'skipped.xml'
        Set-Content $path '<testsuite><testcase><skipped/></testcase></testsuite>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }

    It 'rejects a failing test even when the declared count says zero failures' {
        $path = Join-Path $TestDrive 'failure.xml'
        Set-Content $path '<testsuite failures="0"><testcase><failure message="failed"/></testcase></testsuite>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }

    It 'rejects test errors' {
        $path = Join-Path $TestDrive 'error.xml'
        Set-Content $path '<testsuite><testcase><error message="broken"/></testcase></testsuite>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }

    It 'rejects suite-level failures without failure elements' {
        $path = Join-Path $TestDrive 'suite-error.xml'
        Set-Content $path '<testsuite errors="1"><testcase/></testsuite>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }

    It 'rejects external entities' {
        $path = Join-Path $TestDrive 'entity.xml'
        Set-Content $path '<!DOCTYPE testsuite [<!ENTITY xxe SYSTEM "file:///C:/Windows/win.ini">]><testsuite><testcase>&xxe;</testcase></testsuite>'
        { & $validator -ReportPath $path -MinimumTests 1 } | Should Throw
    }
}
