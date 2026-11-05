# N1410 installation settings. Environment overrides are supported.
epicsEnvSet("PV_LOCATION", "$(PV_LOCATION=FHF1)")
epicsEnvSet("MUSIC_PREFIX", "$(MUSIC_PREFIX=SFRS:$(PV_LOCATION):MUSIC1:)")
epicsEnvSet("MUSIC_SUBSTITUTIONS", "$(MUSIC_SUBSTITUTIONS=db/music_hv_$(PV_LOCATION).substitutions)")
epicsEnvSet("CAEN_PORT", "$(CAEN_PORT=MUSIC_N1410)")
epicsEnvSet("CAEN_DEVICE", "$(CAEN_DEVICE=/dev/ttyUSB0)")
epicsEnvSet("CAEN_BD", "$(CAEN_BD=00)")
epicsEnvSet("CAEN_BAUD", "$(CAEN_BAUD=9600)")
# Hardware maxima: 1000 V, 200 uA. Lower to approved detector limits.
# In low current range (Imon Zoom), use at most 20 uA.
epicsEnvSet("HV_V_SET_MAX", "$(HV_V_SET_MAX=1000)")
epicsEnvSet("HV_I_SET_MAX", "$(HV_I_SET_MAX=200)")
