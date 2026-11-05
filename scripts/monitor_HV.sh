#!/usr/bin/env bash
set -euo pipefail
location=${PV_LOCATION:-FHF1}
prefix=${MUSIC_PREFIX:-SFRS:${location}:MUSIC1:}
case "$location" in FHF1) count=3 ;; FMF1) count=2 ;; *) echo 'Unknown PV_LOCATION' >&2; exit 1 ;; esac
for ((fc=1; fc<=count; fc++)); do
    caget "${prefix}FC${fc}:HV_V_RBV" "${prefix}FC${fc}:HV_I_RBV" \
          "${prefix}FC${fc}:HV_V_SET" "${prefix}FC${fc}:HV_I_SET" \
          "${prefix}FC${fc}:HV_STATUS"
done
