#!/bin/bash
# Post script to verify the primary function of the Framemanipulator
# $ tbFmIpCore.sh [SETTINGS_FILE]

# Needed parameters of the setting file:
# GEN_FILE_STIM:    Frames of the stimulation file
# GEN_FILE_FM:      Frames out of the Framemanipulator
# GEN_FILE_TIME:    Delay of the outgoing frames
# TEST*:            One of the test functions

# Test PassFrame: Test without manipulations: Frames shouldn't be distorted, Jitter isn't allowed


# Function load sources:
function loadTestSources()
{
    #Select files for this test
    GEN_FILE_STIM_TEST=$GEN_FILE_STIM$TEST_NR
    GEN_FILE_FM_TEST=$GEN_FILE_FM$TEST_NR
    GEN_FILE_TIME_TEST=$GEN_FILE_TIME$TEST_NR


    #Check and import generated files from testbench
    if ! test -s $GEN_FILE_STIM_TEST
    then
        echo -e "\n\e[31mERROR: Output file $GEN_FILE_STIM_TEST is empty\e[0m"
        exit 1

    fi

    if ! test -s $GEN_FILE_FM_TEST
    then
        echo -e "\n\e[31mERROR: Output file $GEN_FILE_FM_TEST is empty\e[0m"
        exit 1

    fi

    if ! test -s $GEN_FILE_TIME_TEST
    then
        echo -e "\n\e[31mERROR: Output file $GEN_FILE_TIME_TEST is empty\e[0m"
        exit 1

    fi


    #Load files
    source $GEN_FILE_STIM_TEST
    source $GEN_FILE_FM_TEST
    source $GEN_FILE_TIME_TEST
}

# Function PassFrame: Test without manipulations: Frames shouldn't be distorted, Jitter isn't allowed
function passFrame
{
    echo -e "\n\e[36mTest $TEST_NR: Check if Ethernet stream is distorted\e[0m"

     #Check if the number of ingoing and outgoing frames is the same:
    if (($NR_OF_FRAME != $NR_OF_FM_FRAME)); then
        echo "ERROR: Not all frames passed the FM. $NR_OF_FM_FRAME passed instead of $NR_OF_FRAME"
        exit 1

    else
        echo "All frames passed the FM"

    fi

    #Check if Frames were distorted:
    echo "Check the data of the $NR_OF_FRAME frames:"

    for ((NR=1; NR<=$NR_OF_FRAME; NR++))
    do
        FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
        FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

        if [ "${FRAME_STIM[*]}" != "${FRAME_FM[*]}" ]; then
            echo -e "\n\e[31mERROR: Mismatch of frame $NR\e[0m"
            exit 1

        else
            echo "Frame $NR is the same"

        fi

    done



    #Check if there is Jitter:
    echo "Check the frame delay:"

    NR=1
    FRAME_DELAY=$(eval "echo \${FRAME_DELAY"$NR[*]})
    echo "Delay of frame $NR: $FRAME_DELAY"

    for ((NR=2; NR<=$NR_OF_FRAME; NR++))
    do
        FRAME_OLD_DELAY=$FRAME_DELAY
        FRAME_DELAY=$(eval "echo \${FRAME_DELAY"$NR[*]})

        echo "Delay of frame $NR: $FRAME_DELAY"

        if [ "$FRAME_OLD_DELAY" != "$FRAME_DELAY" ]; then
            echo -e "\n\e[31mERROR: Jitter at frame $NR\e[0m"
            exit 1

        fi

    done
}


#Load settings file
SETTINGS_FILE=$1
source $SETTINGS_FILE


#Start behaviour test
echo -e "\nExecute simulation post-script:"


TEST_NR=1
while [ "$(eval "echo \${TEST"$TEST_NR[*]})" ]
do

    loadTestSources

    $(eval "echo \${TEST"$TEST_NR[*]})

    TEST_NR=$(($TEST_NR+1))

done



exit 0