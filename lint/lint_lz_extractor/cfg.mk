# common design options
# verilator, iverilog, vcs, modelsim
COM_SIM_OPTS := vcs
# user define options +define+;+incdir+
COM_USR_OPTS :=

# top module for RTL
TOP_MODULE := lz_extractor
# RTL file list
RTL_LIST := -f /mnt/hgfs/VMShare/code/inflate-core/rtl.lst
# CBB list file for common design
CBB_LIST :=
# simulate file list
SIM_LIST :=
# synthsis file list
SYN_LIST :=
# sdc
SDC_FILE := /mnt/hgfs/VMShare/code/inflate-core/lint/lint_lz_extractor/cm.sdc
# sgdc

# target libary
TARGET_LIBRARY_FILES:=
# waiver file for spyglass
WAIVER_FILE :=

#Add memory and other hard macro db here
ADD_LINK_LIB := [list \
]

#ADD_LINK_LIB := [list \
#/xx/yy/zz.db \
#/xx/yy/aa.db \
#]

# file list group
OPTS_SIM_LIST := ${CMODE_LIST} ${CBB_LIST} ${SIM_LIST} ${RTL_LIST}
OPTS_CMP_LIST := ${CBB_LIST} ${SIM_LIST} ${RTL_LIST}
