TOP = ../..

include $(TOP)/configure/CONFIG

PROD_IOC = musicN1410

DBD += musicN1410.dbd
musicN1410_DBD += base.dbd
musicN1410_DBD += asyn.dbd
musicN1410_DBD += drvAsynSerialPort.dbd
musicN1410_DBD += stream.dbd

musicN1410_SRCS += musicN1410_registerRecordDeviceDriver.cpp
musicN1410_SRCS_DEFAULT += musicN1410Main.cpp
musicN1410_SRCS_vxWorks += -nil-

musicN1410_LIBS += stream
musicN1410_LIBS += asyn
musicN1410_LIBS += $(EPICS_BASE_IOC_LIBS)

include $(TOP)/configure/RULES
