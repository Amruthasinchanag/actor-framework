#!/usr/bin/env bash
set -Eeuo pipefail

mode="${1:-}"
if [[ "$mode" != setup && "$mode" != test ]]; then
    echo "Usage: bash invoke-lunit-container.sh {setup|test}" >&2
    exit 2
fi
if [[ ! "${LV_YEAR:-}" =~ ^[0-9]{4}$ ]] || (( LV_YEAR < 2026 )); then
    echo "LV_YEAR must identify LabVIEW 2026 or later for headless execution." >&2
    exit 2
fi

log_root=/unit-test-results
mkdir -p "$log_root"
exec > >(tee -a "$log_root/$mode.log") 2>&1
trap 'status=$?; echo "LUnit container step failed at line $LINENO (exit $status)." >&2; exit "$status"' ERR

lv_root="/usr/local/natinst/LabVIEW-${LV_YEAR}-64"
labview="$lv_root/labviewprofull"
if [[ ! -x "$labview" ]]; then
    echo "Required LabVIEW executable not found: $labview" >&2
    exit 1
fi
command -v LabVIEWCLI

if [[ "$mode" == setup ]]; then
    export DEBIAN_FRONTEND=noninteractive
    export VIPM_NONINTERACTIVE=1 VIPM_TIMEOUT=900 NO_COLOR=1
    for name in VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL; do
        if [[ -z "${!name:-}" ]]; then
            echo "Required VIPM Pro activation environment variable is missing: $name" >&2
            exit 1
        fi
    done

    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl xvfb x11-utils
    if ! command -v vipm > /dev/null; then
        installer=$(mktemp --suffix=.deb)
        trap 'rm -f -- "$installer"' EXIT
        curl --fail --location --retry 3 \
            https://packages.jki.net/vipm/preview/vipm_latest_preview_amd64.deb \
            --output "$installer"
        apt-get install -y "$installer"
        rm -f -- "$installer"
        trap - EXIT
    fi
    command -v vipm
fi

# VIPM's runtime needs Xvfb and NI's container marker even with headless LabVIEW.
export DISPLAY=:99
mkdir -p /tmp/natinst
echo 1 > /tmp/natinst/LVContainer.txt
Xvfb "$DISPLAY" -screen 0 1280x720x24 -ac +extension GLX +render -noreset \
    > "$log_root/xvfb-$mode.log" 2>&1 &
xvfb_pid=$!
display_ready=false
for (( attempt=0; attempt<30; attempt++ )); do
    if ! kill -0 "$xvfb_pid" 2>/dev/null; then
        echo "Xvfb exited. See xvfb-$mode.log." >&2
        exit 1
    fi
    if xdpyinfo -display "$DISPLAY" > /dev/null 2>&1; then
        display_ready=true
        break
    fi
    sleep 1
done
if [[ "$display_ready" != true ]]; then
    echo "Xvfb did not become ready within 30 seconds." >&2
    exit 1
fi

if [[ "$mode" == setup ]]; then
    # Never publish activation output or include the command in shell tracing.
    activation_log=$(mktemp)
    trap 'rm -f -- "$activation_log"' EXIT
    if vipm activate --serial-number "$VIPM_SERIAL_NUMBER" \
        --name "$VIPM_FULL_NAME" --email "$VIPM_EMAIL" > "$activation_log" 2>&1; then
        echo "VIPM Pro activation succeeded."
    else
        status=$?
        echo "VIPM Pro activation failed (exit $status). Check credentials and entitlement." >&2
        exit "$status"
    fi
    rm -f -- "$activation_log"
    trap - EXIT
    unset VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL

    vipm version
    vipm refresh
    "$labview" --headless > "$log_root/labview-setup.log" 2>&1 &
    labview_pid=$!
    labview_ready=false
    for (( attempt=0; attempt<90; attempt++ )); do
        if ! kill -0 "$labview_pid" 2>/dev/null; then
            echo "Headless LabVIEW exited before package installation. See labview-setup.log." >&2
            exit 1
        fi
        if (echo > /dev/tcp/127.0.0.1/3363) 2>/dev/null; then
            labview_ready=true
            break
        fi
        sleep 2
    done
    if [[ "$labview_ready" != true ]]; then
        echo "Headless LabVIEW did not open VI Server port 3363 within three minutes." >&2
        exit 1
    fi

    vipm install -y astemes_lib_lunit astemes_lib_lunit_cli \
        --labview-version "$LV_YEAR" --labview-bitness 64
    vipm list --installed --labview-version "$LV_YEAR" --labview-bitness 64 |
        tee "$log_root/installed-packages.log"
    operation="$lv_root/vi.lib/Astemes/LUnit CLI/LUnitCLI"
    if [[ ! -d "$operation" ]]; then
        echo "The native LUnit CLI operation was not installed at $operation" >&2
        exit 1
    fi
    exit 0
fi

project="/actor-framework/Core/Actor Framework Core.lvproj"
if [[ ! -f "$project" || ! -d "/actor-framework/Test/Unit Tests" ]]; then
    echo "The migrated LUnit project or test suite is missing." >&2
    exit 1
fi

cd /actor-framework
LabVIEWCLI -OperationName LUnit \
    -LabVIEWPath "$labview" \
    -AdditionalOperationDirectory "$lv_root/vi.lib/Astemes/LUnit CLI" \
    -Path "$project" \
    -ReportPath "$log_root/lunit.xml" \
    -LogToConsole TRUE \
    -Headless
