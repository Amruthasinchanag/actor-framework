# LUnit tests in a Linux LabVIEW container

[LUnit Tests on LV Container](../.github/workflows/lunit-container-tests.yml)
runs on pushes, pull requests, and manual dispatch. It is independent of the
existing CI and legacy unit-test workflows.

## Prerequisites

- The LUnit migration from [PR #159](https://github.com/ni/actor-framework/pull/159).
  This development branch starts at GitHub's merge preview,
  `f976f77abf62df76a6d493e37532b6fe6ad29972`, combining migration head
  `aafd2ac1e68db9dfbc54ce5af7633f41f4c5caff` with the target branch.
  It also merges fork `develop` at `71271cd` and includes NI `develop` at
  `230ab1b`. The fork's existing host-installed LUnit workflow is retained;
  this container workflow does not replace it.
  The workflow expects the migrated core project and `Test/Unit Tests`.
- A Linux runner with a working Docker engine.
  The workflow uses `ubuntu-22.04` and the published
  `nationalinstruments/labview:2026q1patch1-linux` image (64-bit).
- Authorized LabVIEW container usage under NI's license terms.
- A VIPM Pro entitlement for JKI's documented container automation flow.
  Configure repository secrets `VIPM_SERIAL_NUMBER`, `VIPM_FULL_NAME`, and
  `VIPM_EMAIL`. Missing secrets fail before downloading the image.
- Network access to Docker Hub, the JKI installer, VIPM package feeds, and
  activation services.

Fork PRs fail with an explicit prerequisite message: they cannot receive VIPM
activation secrets. Review the contribution and push it to a trusted repository
branch to test it. Do not use `pull_request_target` to run untrusted code with
secrets. Repository branches and same-repository PRs must be trusted; changes to
this workflow and its scripts can access the configured secrets.

## Execution

The NI image already supplies LabVIEW and native LabVIEW CLI. The workflow:

1. Checks Docker and the image's Linux/amd64 metadata and `LV_YEAR`.
2. Starts a uniquely named container and verifies it responds to `docker exec`.
3. Runs [the Bash bootstrap script](../pipeline/scripts/invoke-lunit-container.sh)
   as root, installs JKI's Linux VIPM `.deb` and its dependencies, and starts
   Xvfb on display `:99`. It writes `/tmp/natinst/LVContainer.txt`, waits for the
   display, activates Pro, starts headless LabVIEW, and waits for VI Server.
   It then installs `astemes_lib_lunit` and `astemes_lib_lunit_cli` for 64-bit
   LabVIEW. Command failures are based on exit status, not output on stderr.
4. Restarts the container to discard the LabVIEW instance used by VIPM.
5. Copies the repository, starts a fresh Xvfb display, and runs the source project through
   `LabVIEWCLI -OperationName LUnit -Path ... -ReportPath ... -Headless`.
   The explicit additional operation directory avoids relying on system-wide
   registration. `-Headless` must remain the last argument.
6. Collects JUnit XML and logs, validates the report on the host using PowerShell,
   rejects failures/errors or fewer than 13 executed tests, uploads results for
   seven days, and removes the container.

Setup and test output is logged from the start of each mode. A host-side lifecycle
log is created before container startup and Docker logs are collected even if
setup fails, so an early failure does not leave an empty artifact directory.
Activation output is excluded from these logs. The `.gitattributes` rule preserves
LF line endings for shell scripts checked out on Windows.

G-CLI, Caraya, and the NI Unit Test Framework Toolkit are not required by this
runner. The workflow does not test an installed distribution; it tests the source
project. No image is committed or published, and activation credentials are only
passed to the setup process, never to the test execution process or container
configuration. Activation output is not uploaded.

The LabVIEW release is pinned. The VIPM installer currently uses JKI's official
latest-preview URL, and packages resolve from the current VIPM feed. The
installed package inventory is uploaded for diagnosis; these dependencies are
not yet version-locked. Validate a successful CI run before making this a
required check. Package compatibility, activation, and headless execution must be
verified on the actual runner. Switching from Windows to Linux also changes the
platform under test; this is not a substitute for Windows test coverage. Linux
uses case-sensitive paths, and any Windows-only source dependencies need separate
investigation if project loading fails.

## Validation

Run the report-validator regression tests from the repository root using
Windows PowerShell's bundled Pester 3.4 (or Pester 4):

```powershell
Invoke-Pester .\pipeline\tests\Assert-LUnitReport.Tests.ps1
```

Then push the branch and inspect **Actions > LUnit Tests on LV Container**.
Download the `lunit-results-<run>-<attempt>` artifact. A green job requires a
successful LabVIEW CLI exit and a valid report with at least the migration's
13 executed tests. Update that threshold deliberately if the suite changes.

## References

- [NI Linux container requirements](https://github.com/ni/labview-for-containers/blob/main/docs/linux-prebuilt.md)
- [Native LUnit CLI installation and usage](https://github.com/Astemes/astemes-lunit-cli)
- [VIPM Docker setup and Pro activation](https://docs.vipm.io/latest/cli/docker/)
- [JKI Linux container example](https://github.com/vipm-io/examples-vipm-docker/tree/main/examples/ni_labview_official_container_with_vipm)
