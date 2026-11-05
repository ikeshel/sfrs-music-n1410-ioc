# CAEN N1410 MUSIC IOC

Standalone EPICS Base 7 IOC using asyn and StreamDevice, adapted from
`../sfrs-music-ndt1470-ioc`. Source files were copied without Git history,
binaries, generated databases or IOC shell history.

## Hardware and protocol

[CAEN N1410 specifications](https://caen.it/products/n1410/) give four channels,
1000 V magnitude, 200 µA (high range) or 20 µA (low range / Imon Zoom),
20 mV voltage resolution, 5 nA current-set resolution and 1–100 V/s ramps.
Imon Zoom resolves 0.5 nA. Polarity is selected internally on the module;
the IOC writes nonnegative voltage magnitudes and does not change polarity.

`musicN1410App/Db/caen_n1410.proto` implements the reference's N14xx ASCII
command family: `$BD:00,CMD:MON,CH:0,PAR:VMON` and
`$BD:00,CMD:SET,CH:0,PAR:VSET,VAL:12.34`, with `#BD:00,CMD:OK`
acknowledgements and `,VAL:...` on monitor replies. Commands and replies use
CR LF. The NDT1470-specific LF CR SET acknowledgement workaround was removed.
Voltage writes retain two decimal places; current writes retain three (µA).
The device determines quantization to its supported resolution.

**Commissioning limitation:** the public N1410 specifications confirm the
ranges and resolutions, but an N1410-specific protocol manual was not available
for this adaptation. Command compatibility, CR LF reply framing, serial settings,
voltage sign convention and status bit meanings must be checked against the
installed firmware/manual. The serial simulator validates the implemented
contract, not real hardware compatibility. Status is exposed as a raw decimal
mask; no unverified NDT1470 bit table is carried over.

## Build

Dependencies default to `../../base-7.0.10`, `../../support/asyn` and
`../../support/StreamDevice`, relative to this project. Edit `configure/RELEASE`
or pass `EPICS_BASE`, `ASYN` and `STREAM` to make.

```bash
make -j2
```

The executable is `bin/linux-x86_64/musicN1410`. The database and protocol
sources live only in `musicN1410App/Db`; make installs them into ignored `db/`.
Edit the sources, then rebuild. Do not edit generated files in `db/`.

## Configure and run

The reference's mapping is preserved: `x86l-260` selects FMF1 (FC1–FC2),
`x86l-261` selects FHF1 (FC1–FC3). Other hosts require `PV_LOCATION`.
FC1 maps to CH0, FC2 to CH1 and FC3 to CH2. CH3 is unused unless explicitly
added to a substitutions file. The template supports all four hardware channels.

```bash
PV_LOCATION=FHF1 \
CAEN_DEVICE=/dev/serial/by-id/YOUR_N1410_DEVICE \
HV_V_SET_MAX=500 HV_I_SET_MAX=120 ./run.sh
```

Choose the correct device with `ls -l /dev/serial/by-id/`. The default for the supplied installation is
`/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AB0OC33S-if00-port0`; the old NDT1470 USB identifier is not assumed to identify an
N1410. The account needs read/write access (normally membership in `dialout`).
Stop other serial clients before starting this IOC.

Settings are in `iocBoot/iocmusicN1410/settings.cmd` and accept environment
overrides:

| Variable | Default / meaning |
|---|---|
| `PV_LOCATION` | Selected by hostname in run.sh; FHF1 in direct startup |
| `MUSIC_PREFIX` | `SFRS:<PV_LOCATION>:MUSIC1:` |
| `MUSIC_SUBSTITUTIONS` | `db/music_hv_<PV_LOCATION>.substitutions` |
| `CAEN_DEVICE` | `/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AB0OC33S-if00-port0` |
| `CAEN_PORT` | `MUSIC_N1410` |
| `CAEN_BD` | `00` (two digits, 00–31) |
| `CAEN_BAUD` | `9600`; 8N1, XON/XOFF |
| `HV_V_SET_MAX` | `500` V (positive operating limit) |
| `HV_I_SET_MAX` | `200` µA; lower to ≤20 with Imon Zoom |
| `EPICS_CAS_SERVER_PORT` | `5064` |

Set voltage/current limits to the approved detector operating envelope. The
launcher rejects voltage limits above 500 V and current limits above 200 µA, invalid addresses and missing
devices. Direct startup bypasses launcher validation:

```bash
cd iocBoot/iocmusicN1410
../../bin/linux-x86_64/musicN1410 st.cmd
```

Do not run another IOC with the same PV prefix. Use `MUSIC_PREFIX` to separate
test or simultaneous installations. Stop with `exit` or Ctrl+C. Stopping the IOC
does not turn off hardware outputs.

## PV interface

Names are `<MUSIC_PREFIX>FC<n>:<suffix>` (including the `PHV:` subsystem below):

| Suffix | Function |
|---|---|
| `PHV:V_SET` | Voltage magnitude setpoint, 0–configured maximum V |
| `PHV:V_RBV` | Measured voltage, V |
| `PHV:I_SET` | Current limit, 0–configured maximum µA |
| `PHV:I_RBV` | Measured current, µA (four displayed decimals) |
| `PHV:RAMP_UP_SET` | Ramp-up rate, 1–100 V/s |
| `PHV:RAMP_DOWN_SET` | Ramp-down rate, 1–100 V/s |
| `PHV:ENABLE` | Write 0 for OFF, 1 for ON |
| `PHV:STATUS` | Raw decimal status mask, sampled once per second |

Every canonical record has a readable alias, for example
`FC1:PHV:V_SET` and `FC1:POSITIVE:V_SET` access the same record.
The same mapping applies to all eight suffixes above. Use `PHV` in displays
and scripts. Legacy `HV_*` names and ambiguous ON/OFF aliases are removed.
`PHV:ENABLE` is the last command, not actual channel state; inspect
`PHV:STATUS` for hardware state.

All output records have `PINI=NO`. StreamDevice initialization queries voltage,
current and both ramp setpoints; it never sends SET or ON/OFF at startup.
Successful setpoint writes are followed by a hardware query. EPICS analog-output
limits clamp out-of-range writes; check the accepted value and record alarm.
Timeouts, rejected commands and malformed responses cause record alarms.
No autosave or automatic startup ramp defaults are applied.

```bash
PV_LOCATION=FHF1 scripts/monitor_HV.sh
caget SFRS:FHF1:MUSIC1:FC1:PHV:V_SET.SEVR
# Only after checking wiring, polarity, interlock and approved limits:
caput SFRS:FHF1:MUSIC1:FC1:PHV:V_SET 10
caput SFRS:FHF1:MUSIC1:FC1:PHV:ENABLE 1
caput SFRS:FHF1:MUSIC1:FC1:PHV:ENABLE 0
```

A voltage write while ON changes the output immediately via the configured ramp.
Software limits do not replace hardware VMAX, current protection or interlocks.
The IOC does not configure polarity, current range, VMAX or trip behavior.

For commissioning, add before `iocInit` in `st.cmd`:

```iocsh
asynSetTraceIOMask("$(CAEN_PORT)", -1, 0x2)
asynSetTraceMask("$(CAEN_PORT)", -1, 0x9)
```

Confirm board address, local-bus baud rate, remote control mode and reply line
endings using read-only MON commands before applying setpoints. Remove tracing
after verification.

## Verification

```bash
bash -n run.sh scripts/monitor_HV.sh
python3 tests/test_serial.py
```

The Linux PTY integration test starts the real built IOC with a simulated device
and localhost Channel Access on port 15064. It checks both channel mappings,
read-only initialization, setpoint formatting, limit clamping, ON/OFF commands
and rejected-write alarms. It requires permission to open localhost sockets.
No physical N1410 was used for these tests.

## Polarity naming migration

Canonical PVs use `FC<n>:PHV:<parameter>`; every record also has a
`FC<n>:POSITIVE:<parameter>` alias. Parameters are `V_SET`, `V_RBV`,
`I_SET`, `I_RBV`, `RAMP_UP_SET`, `RAMP_DOWN_SET`, `ENABLE` and `STATUS`.
For example, `SFRS:FHF1:MUSIC1:FC1:POSITIVE:V_RBV` is the same record
as `SFRS:FHF1:MUSIC1:FC1:PHV:V_RBV`.

Update clients from `FC1:HV_V_RBV` to `FC1:PHV:V_RBV` and from
`FC1:HV_STATE` to `FC1:PHV:STATUS`. Old `HV_*` aliases are not provided,
so the positive and negative IOCs can share the MUSIC prefix without collisions.
Rebuild and restart both IOCs to load the new names. This naming change does
not alter hardware polarity or the protocol's voltage sign convention.
