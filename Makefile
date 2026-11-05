TOP = .

include $(TOP)/configure/CONFIG

DIRS := configure
DIRS += musicN1410App
DIRS += iocBoot

include $(TOP)/configure/RULES_TOP
