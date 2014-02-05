#!/bin/bash
# Runs modelsim to compile and simulate provided sources and toplevel.
# Call e.g. ./tools/msim-sim.sh SETTING-FILE

proc_genList() {
    export GENLIST=

    for i in $*
    do
        GENLIST+="-g$i "
        shift
    done
}

# Get *.settings file
SETTINGS_FILE=$1
DIR_TOOLS=$2

# Set defaults
SRC_LIST=
TOP_LEVEL=
GEN_LIST=("")
VCOM_LIST=
VSIM_LIST=
VHDL_STD="-93"

# Get parameters from *.settings file
source $SETTINGS_FILE

DOFILE=$DIR_TOOLS/sim.do

echo
echo "#### $TOP_LEVEL ####"

vlib work

#compile source files
vcom $VHDL_STD -work work $SRC_LIST $VCOM_LIST -check_synthesis
if test $? -ne 0
then
    exit 1
fi

CNT=0
for i in  "${GEN_LIST[@]}"
do
    proc_genList $i

    #simulate design
    vsim $TOP_LEVEL -c -do $DOFILE -lib work $GENLIST $VSIM_LIST

    #catch simulation return
    RET=$?

    echo
    if [ $RET -ne 0 ]; then
        echo "ERROR"
        exit $RET
    else
        echo "PASS"
    fi
    CNT=$(( CNT + 1 ))
done


#Execute post script, when defined
if [ "$POST_SCRIPT" ]; then
    chmod +x $POST_SCRIPT
    $POST_SCRIPT $SETTINGS_FILE|| {
        echo "Post-Scrip failed"
        exit 1
    }

fi


#exit with simulation return
exit $RET
