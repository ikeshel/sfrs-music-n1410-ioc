#!../../bin/linux-x86_64/musicN1410

#
# i.keshelashvili@gsi.de
#

< envPaths

cd "$(TOP)"

dbLoadDatabase "dbd/musicN1410.dbd"
musicN1410_registerRecordDeviceDriver pdbbase

< iocBoot/iocmusicN1410/settings.cmd

epicsEnvSet("STREAM_PROTOCOL_PATH", "$(TOP)/db")

drvAsynSerialPortConfigure("$(CAEN_PORT)", "$(CAEN_DEVICE)", 0, 0, 0)
asynSetOption("$(CAEN_PORT)", -1, "baud",    "$(CAEN_BAUD)")
asynSetOption("$(CAEN_PORT)", -1, "bits",    "8")
asynSetOption("$(CAEN_PORT)", -1, "parity",  "none")
asynSetOption("$(CAEN_PORT)", -1, "stop",    "1")
asynSetOption("$(CAEN_PORT)", -1, "clocal",  "Y")
asynSetOption("$(CAEN_PORT)", -1, "crtscts", "N")
asynSetOption("$(CAEN_PORT)", -1, "ixon",    "Y")
asynSetOption("$(CAEN_PORT)", -1, "ixoff",   "Y")

#
dbLoadTemplate( \
    "$(MUSIC_SUBSTITUTIONS)", \
    "P=$(MUSIC_PREFIX),PORT=$(CAEN_PORT),BD=$(CAEN_BD),VMAX=$(HV_V_SET_MAX),IMAX=$(HV_I_SET_MAX)" \
)

iocInit
