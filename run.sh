#!/usr/bin/env bash
set -euo pipefail
ioc_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ioc_arch=${EPICS_HOST_ARCH:-linux-x86_64}
ioc_binary="$ioc_root/bin/$ioc_arch/musicN1410"
if [[ -z ${PV_LOCATION:-} ]]; then
    case "$(hostname -s | tr '[:upper:]' '[:lower:]')" in
        x86l-260) export PV_LOCATION=FMF1 ;;
        x86l-261) export PV_LOCATION=FHF1 ;;
        *) echo 'Set PV_LOCATION=FHF1 or FMF1 for this host.' >&2; exit 1 ;;
    esac
fi
case "$PV_LOCATION" in FHF1|FMF1) ;; *) echo 'PV_LOCATION must be FHF1 or FMF1.' >&2; exit 1 ;; esac
export MUSIC_PREFIX=${MUSIC_PREFIX:-SFRS:${PV_LOCATION}:MUSIC1:}
export MUSIC_SUBSTITUTIONS=${MUSIC_SUBSTITUTIONS:-db/music_hv_${PV_LOCATION}.substitutions}
export CAEN_DEVICE=${CAEN_DEVICE:-/dev/ttyUSB0}
export CAEN_BD=${CAEN_BD:-00}
export HV_V_SET_MAX=${HV_V_SET_MAX:-1000}
export HV_I_SET_MAX=${HV_I_SET_MAX:-200}
export EPICS_CAS_SERVER_PORT=${EPICS_CAS_SERVER_PORT:-5064}
# Catch configuration mistakes before opening a hardware connection.
python3 - <<'PY'
import os, re
for name, maximum in [('HV_V_SET_MAX', 1000), ('HV_I_SET_MAX', 200)]:
    try:
        value = float(os.environ[name])
        assert 0 < value <= maximum
    except (ValueError, AssertionError):
        raise SystemExit(f'{name} must be greater than 0 and at most {maximum}')
if not re.fullmatch(r'(?:[0-2][0-9]|3[01])', os.environ['CAEN_BD']):
    raise SystemExit('CAEN_BD must be a two-digit address 00..31')
PY
[[ -x "$ioc_binary" ]] || { echo "Build the IOC first: make" >&2; exit 1; }
[[ -r "$CAEN_DEVICE" && -w "$CAEN_DEVICE" ]] || { echo "Serial device unavailable: $CAEN_DEVICE (set CAEN_DEVICE to its /dev/serial/by-id link)" >&2; exit 1; }
cd "$ioc_root"
[[ -r "$MUSIC_SUBSTITUTIONS" ]] || { echo "Missing substitutions: $MUSIC_SUBSTITUTIONS" >&2; exit 1; }
echo "Starting MUSIC N1410: $MUSIC_PREFIX on $CAEN_DEVICE, board $CAEN_BD"
cd iocBoot/iocmusicN1410
exec "$ioc_binary" st.cmd
