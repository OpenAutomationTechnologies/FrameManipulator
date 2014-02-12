#!/bin/bash
# Post script to verify the primary function of the Framemanipulator
# $ tbFmIpCore.sh [SETTINGS_FILE]

# Needed parameters of the setting file:
# GEN_FILE_STIM:    Frames of the stimulation file
# GEN_FILE_FM:      Frames out of the Framemanipulator
# GEN_FILE_TIME:    Delay of the outgoing frames
# TEST*:            One of the test functions

# Test PassFrame:                   Test without manipulations: Frames shouldn't be distorted, Jitter isn't allowed
# Test DropSocCycle2:               Drop of the second SoC
# Test delay25UsPResCycle1Type1:    Delay of the first PRes of 25 µs with storing all overlapping frames


#Constants
#22th byte of recorded frame is message type (Header+Preamble)
MESSAGE_TYPE=22

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
        echo -e "\n\e[31mERROR: Not all frames passed the FM. $NR_OF_FM_FRAME passed instead of $NR_OF_FRAME\e[0m"
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

# Function dropSocCycle2: Drop of the second SoC
function dropSocCycle2
{
    DROP_M_TYPE="SoC"
    DROP_CYCLE=2
    dropManipulation
}

#Function for drop manipulation
#Predefined variables: DROP_M_TYPE for type; DROP_CYCLE for cycle
function dropManipulation
{
    echo -e "\n\e[36mTest $TEST_NR: Check Drop-task of second SoC\e[0m"

    #Check if the one frame is missing:
    if (($NR_OF_FRAME != $(($NR_OF_FM_FRAME+1)) )); then

        if (($NR_OF_FRAME == $NR_OF_FM_FRAME )); then
            echo -e "\n\e[31mERROR: All $NR_OF_FM_FRAME frames passed the FM. No drop occurred\e[0m"
            exit 1

        else
            echo -e "\n\e[31mERROR: More than one frame is missing. $NR_OF_FM_FRAME passed instead of $NR_OF_FRAME\e[0m"
            exit 1

        fi

    else
        echo "Missing of one frame confirmed"

    fi


    #Check Ethernet frames

    #Testcycle
    CYCLE=0
    for ((NR=1, NR_FM=1 ; NR<=$NR_OF_FRAME; NR++))
    do

        #Load MessageType of stimulated frame and count up cycle at SoC
        MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR[$MESSAGE_TYPE]})

        case $MESSAGE_TYPE_STIM in
        01)
            TYPE_STIM="SoC"
            CYCLE=$(($CYCLE+1))
            ;;
        03)
            TYPE_STIM="PReq"
            ;;
        04)
            TYPE_STIM="PRes"
            ;;
        05)
            TYPE_STIM="SoA"
            ;;
        06)
            TYPE_STIM="ASnd"
            ;;
        *)
            TYPE_STIM="unknown frame"
            ;;
        esac

        #Output detected stimulation frame
        echo "Stimulated frame $NR is a $TYPE_STIM of test cycle $CYCLE"

        #Stimulated frame is the dropped one?
        if [ $TYPE_STIM == $DROP_M_TYPE -a $CYCLE == $DROP_CYCLE ]; then
        #true:

            echo -e "\e[33mThis frame is the dropped one\e[0m"

        else
        #false:

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR_FM[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR_FM is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR_FM\e[0m"
                exit 1

            fi

            #Count FM frame up
            NR_FM=$(($NR_FM+1))
        fi

    done

}

# Function delay25UsPResCycle1Type1:    Delay of the first PRes of 25 µs with storing all overlapping frames
function delay25UsPResCycle1Type1
{
    DELAY_M_TYPE="PRes"
    DELAY_CYCLE=1
    DELAY_TIME=25000
    frameDelay1
}

# Function for frame delay manipulation with delay type 1
# Check of configured delay via delay of first SoC as reverence
# Predefined variables: DELAY_M_TYPE for messageType; DELAY_CYCLE for cycle; DELAY_TIME for the configured delay in ns
function frameDelay1
{
    echo -e "\n\e[36mTest $TEST_NR: Check Delay-task of first PRes with DelayType 1 \e[0m"

    #Check if the number of ingoing and outgoing frames is the same:
    if (($NR_OF_FRAME != $NR_OF_FM_FRAME)); then
        echo -e "\n\e[31mERROR: Not all frames passed the FM. $NR_OF_FM_FRAME passed instead of $NR_OF_FRAME\e[0m"
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

    #Check the delay of the manipulated frame:
    echo "Check the delay of the manipulated frame:"

    CYCLE=0
    for ((NR=1, NR_FM=1 ; NR<=$NR_OF_FRAME; NR++))
    do

        #Load MessageType of stimulated frame and count up cycle at SoC
        MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR[$MESSAGE_TYPE]})

        case $MESSAGE_TYPE_STIM in
        01)
            TYPE_STIM="SoC"
            CYCLE=$(($CYCLE+1))
            ;;
        03)
            TYPE_STIM="PReq"
            ;;
        04)
            TYPE_STIM="PRes"
            ;;
        05)
            TYPE_STIM="SoA"
            ;;
        06)
            TYPE_STIM="ASnd"
            ;;
        *)
            TYPE_STIM="unknown frame"
            ;;
        esac

        #Output detected stimulation frame
        echo "Stimulated frame $NR is a $TYPE_STIM of test cycle $CYCLE"

        #Searching for the first SoC to receive a reference value
        if [ $TYPE_STIM == "SoC" -a $CYCLE == 1 ]; then

            REF_DELAY=$(eval "echo \${FRAME_DELAY"$NR[*]})
            echo -e "\e[33mThis is the first SoC with a delay of $REF_DELAY\e[0m"

        fi

        #Stimulated frame is the delayed one?
        if [ $TYPE_STIM == $DELAY_M_TYPE -a $CYCLE == $DELAY_CYCLE ]; then

            MAN_DELAY=$(eval "echo \${FRAME_DELAY"$NR[*]})
            echo -e "\e[33mThis is the manipulated frame with a delay of $MAN_DELAY\e[0m"

            #Remove the "ns"
            SIZE=$((${#MAN_DELAY}-3))
            MAN_DELAY_NEW=${MAN_DELAY:0:$SIZE}

            SIZE=$((${#REF_DELAY}-3))
            REF_DELAY_NEW=${REF_DELAY:0:$SIZE}

            #Check the created delay
            DELAY_DIV=$(($MAN_DELAY_NEW-$REF_DELAY_NEW))

            if (( $DELAY_DIV == $DELAY_TIME )); then
                echo -e "\e[33mThe occurred delay of $DELAY_DIV ns is correct\e[0m"

            else
                echo -e "\n\e[31mERROR: Occurred delay is $DELAY_DIV ns, not $DELAY_TIME ns\e[0m"
                exit 1

            fi

        fi

    done

    #Check IPG
    echo "Check inter packet gap of the Outgoing frames:"

    #Start with 2, first value is the time from simulation start to frame start
    for ((NR=2; NR<=$NR_OF_FM_FRAME; NR++))
    do

        FRAME_GAP=$(eval "echo \${FRAME_GAP"$NR[*]})
        echo "Frame $NR starts after $FRAME_GAP"

        #remove ns
        SIZE=$((${#FRAME_GAP}-3))
        FRAME_GAP=${FRAME_GAP:0:$SIZE}

        if (( $FRAME_GAP < 960 )); then
            echo -e "\n\e[31mERROR: This time is to short \e[0m"
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