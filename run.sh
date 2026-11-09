#!/usr/bin/env bash
set -euo pipefail
ioc_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ioc_arch=${EPICS_HOST_ARCH:-linux-x86_64}
ioc_binary="$ioc_root/bin/$ioc_arch/musicN1410"
ioc_hostname=$(hostname -s | tr '[:upper:]' '[:lower:]')
if [[ -z ${PV_LOCATION:-} ]]; then
    case "$ioc_hostname" in
        x86l-260) export PV_LOCATION=FMF1 ;;
        x86l-261) export PV_LOCATION=FHF1 ;;
        *) echo 'Set PV_LOCATION=FHF1 or FMF1 for this host.' >&2; exit 1 ;;
    esac
fi
case "$PV_LOCATION" in FHF1|FMF1) ;; *) echo 'PV_LOCATION must be FHF1 or FMF1.' >&2; exit 1 ;; esac
export MUSIC_PREFIX=${MUSIC_PREFIX:-SFRS:${PV_LOCATION}:MUSIC1:}
export MUSIC_SUBSTITUTIONS=${MUSIC_SUBSTITUTIONS:-db/music_hv_${PV_LOCATION}.substitutions}
# Each USB adapter has its own serial number; select by host, not PV location.
case "$ioc_hostname" in
    x86l-260) caen_serial=AB0OC33T ;;
    *) caen_serial=AB0OC33S ;;
esac
export CAEN_DEVICE=${CAEN_DEVICE:-/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_${caen_serial}-if00-port0}
export CAEN_BD=${CAEN_BD:-00}
export HV_V_SET_MAX=${HV_V_SET_MAX:-500}
export HV_I_SET_MAX=${HV_I_SET_MAX:-200}
export EPICS_CAS_SERVER_PORT=${EPICS_CAS_SERVER_PORT:-5064}
# Catch configuration mistakes before opening a hardware connection.
python3 - <<'PY'
import os, re
for name, maximum in [('HV_V_SET_MAX', 500), ('HV_I_SET_MAX', 200)]:
    try:
        value = float(os.environ[name])
        assert 0 < value <= maximum
    except (ValueError, AssertionError):
        raise SystemExit(f'{name} must be greater than 0 and at most {maximum}')
if not re.fullmatch(r'(?:[0-2][0-9]|3[01])', os.environ['CAEN_BD']):
    raise SystemExit('CAEN_BD must be a two-digit address 00..31')
PY
[[ -x "$ioc_binary" ]] || { echo "Build the IOC first: make" >&2; exit 1; }
if [[ ! -e "$CAEN_DEVICE" ]]; then
    echo "Serial device missing or dangling link: $CAEN_DEVICE" >&2
    ls -l /dev/serial/by-id/ >&2 2>/dev/null || true
    echo 'Check the USB connection and CAEN_DEVICE path.' >&2
    exit 1
fi
if [[ ! -r "$CAEN_DEVICE" || ! -w "$CAEN_DEVICE" ]]; then
    echo "Serial device exists but this session lacks read/write access: $CAEN_DEVICE" >&2
    ls -lL "$CAEN_DEVICE" >&2
    echo "Current session groups: $(id -Gn)" >&2
    echo 'If the device belongs to dialout, ensure this terminal session has dialout membership.' >&2
    echo 'After a group change, log out and back in, or open a shell with: newgrp dialout' >&2
    exit 1
fi
cd "$ioc_root"
[[ -r "$MUSIC_SUBSTITUTIONS" ]] || { echo "Missing substitutions: $MUSIC_SUBSTITUTIONS" >&2; exit 1; }
echo "Starting MUSIC N1410: $MUSIC_PREFIX on $CAEN_DEVICE, board $CAEN_BD"
cd iocBoot/iocmusicN1410
exec "$ioc_binary" st.cmd
