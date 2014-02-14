#!/bin/bash
# Post script to verify the primary function of the Framemanipulator
# $ tbFmIpCore.sh [SETTINGS_FILE]

# Needed parameters of the setting file:
# GEN_FILE_STIM:    Frames of the stimulation file
# GEN_FILE_FM:      Frames out of the Framemanipulator
# GEN_FILE_TIME:    Delay of the outgoing frames
# TEST*:            One of the test functions

# Test PassFrame:                                           Test without manipulations: Frames shouldn't be distorted, Jitter isn't allowed
# Test DropSocCycle2:                                       Drop of the second SoC
# Test delay25UsPResCycle1Type1:                            Delay of the first PRes of 25 µs with storing all overlapping frames
# Test maniMtype9PResCycle2:                                Changing the MessageType to the value "9" of the PRes in the second Cycle
# Test crcPResCycle2:                                       Distort CRC of PRes in cycle 2
# Test cut50PResCycle2:                                     Cut PRes in cycle 2 to a size of 50 Byte (+CRC+Preamble)
# Test safetyRep2Start41Size11PResCycle3:                   Safety Repetition of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
# Test safetyLoss2Start41Size11PResCycle3:                  Safety Loss of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
# Test safetyInsertion2Start41Size11StartSn52PResCycle3:    Safety Insertion of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Second packet starts at 52. Start at PRes of Cycle 3
# Test safetyIncSeq2Start41Size11PResCycle4:                Safety Incorrect-Sequence of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 4
# Test safetyIncData2Start41Size11PResCycle3:               Safety Incorrect-Data of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
# Test safetyDelay2Start41Size11PResCycle3:                 Safety Delay-task of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3

#Constants
#22th byte of recorded frame is message type (Header+Preamble)
MESSAGE_TYPE=22

#First Byte of safety payload: Byte number 5 (+4)
SAFETY_PAYLOAD=4

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

#Check if the number of ingoing and outgoing frames is the same:
function allFramesPass
{
    if (($NR_OF_FRAME != $NR_OF_FM_FRAME)); then
        echo -e "\n\e[31mERROR: Not all frames passed the FM. $NR_OF_FM_FRAME passed instead of $NR_OF_FRAME\e[0m"
        exit 1

    else
        echo -e "\e[33mAll frames passed the FM\e[0m"

    fi
}

#Check if there is Jitter:
function jitterCheck
{
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

    echo -e "\e[33mNo jitter occurred\e[0m"
}

# Function PassFrame: Test without manipulations: Frames shouldn't be distorted, Jitter isn't allowed
function passFrame
{
    echo -e "\n\e[36mTest $TEST_NR: Check if Ethernet stream is distorted\e[0m"

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

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
    jitterCheck
}

# Function dropSocCycle2: Drop of the second SoC
function dropSocCycle2
{
    DROP_M_TYPE="SoC"
    DROP_CYCLE=2
    echo -e "\n\e[36mTest $TEST_NR: Check Drop-task of second SoC\e[0m"
    dropManipulation
}

#Function for drop manipulation
#Predefined variables: DROP_M_TYPE for type; DROP_CYCLE for cycle
function dropManipulation
{

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
        echo -e "\e[33mMissing of one frame confirmed\e[0m"

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
    echo -e "\n\e[36mTest $TEST_NR: Check Delay-task of first PRes with DelayType 1 \e[0m"
    frameDelay1
}

# Function for frame delay manipulation with delay type 1
# Check of configured delay via delay of first SoC as reverence
# Predefined variables: DELAY_M_TYPE for messageType; DELAY_CYCLE for cycle; DELAY_TIME for the configured delay in ns
function frameDelay1
{

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

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

# Function maniMtype9PResCycle2:        Changing the MessageType to the value "9" of the PRes in the second Cycle
function maniMtype9PResCycle2
{
    MANI_M_TYPE="PRes"
    MANI_CYCLE=2
    NEW_MTYPE=09
    echo -e "\n\e[36mTest $TEST_NR: Check Manipulation-task with changing the MessageType of second PRes\e[0m"
    maniMtype
}

# Function to compare arrays
diff(){
  awk 'BEGIN{RS=ORS=" "}
       {NR==FNR?a[$0]++:a[$0]--}
       END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}

#Function for manipulation of the Messagetype
#Predefined variables: MANI_M_TYPE for frame messageType; MANI_CYCLE for cycle; NEW_MTYPE for new value
function maniMtype
{

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

    #Check frame data

    #Testcycle
    CYCLE=0
    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the manipulated one?
        if [ $TYPE_STIM == $MANI_M_TYPE -a $CYCLE == $MANI_CYCLE ]; then

            echo -e "\e[33mThis frame should be manipulated\e[0m"

            #check new MessageType
            MESSAGE_TYPE_FM=$(eval "echo \${FM_FRAME"$NR[$MESSAGE_TYPE]})

            if [ $MESSAGE_TYPE_FM == $NEW_MTYPE ]; then
                echo -e "\e[33mManipulation is correct\e[0m"

            else
                echo -e "\n\e[31mERROR: Manipulation failed. MessageType is $MESSAGE_TYPE_FM\e[0m"
                exit 1

            fi

            #Check remaining data array
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Compare both arrays
            ARRAY_DIFF=($(diff FRAME_STIM_A[@] FRAME_FM_A[@]))

            #Number of different bytes: (/2 because diff() sends the different entries of both frames)
            NR_DIFF=$((${#ARRAY_DIFF[@]}/2))

            echo -e "\e[33m5 Bytes of the frame should be different (Manipulation+CRC)\e[0m"

            if (( $NR_DIFF > 5 )); then
                echo -e "\n\e[31mERROR: $NR_DIFF bytes are different \e[0m"
                exit 1

            fi


        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck

}

# Function crcPResCycle2:               Distort CRC of PRes in cycle 2
function crcPResCycle2
{
    CRC_TYPE="PRes"
    CRC_CYCLE=2
    echo -e "\n\e[36mTest $TEST_NR: Check Distort-CRC-task with the second PRes\e[0m"
    distortCrc
}

# Function distortCrc:
#Predefined variables: CRC_TYPE for frame messageType; CRC_CYCLE for cycle
function distortCrc
{

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

    #Check frame data

    #Testcycle
    CYCLE=0
    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the manipulated one?
        if [ $TYPE_STIM == $CRC_TYPE -a $CYCLE == $CRC_CYCLE ]; then

            echo -e "\e[33mThis frame should have a wrong CRC\e[0m"

            #Check if manipulation occurred
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Compare whole frames
            if [ "${FRAME_STIM_A[*]}" == "${FRAME_FM_A[*]}" ]; then
                echo -e "\n\e[31mERROR: Frame wasn't manipulated \e[0m"
                exit 1

            fi


            #Remove CRC
            SIZE_MIN_CRC=$((${#FRAME_STIM_A[*]}-4))

            FRAME_STIM_A2=${FRAME_STIM_A[*]:0:$SIZE_MIN_CRC}
            FRAME_FM_A2=${FRAME_FM_A[*]:0:$SIZE_MIN_CRC}

            #Check frame without CRC
            if [ "${FRAME_STIM_A2[*]}" == "${FRAME_FM_A2[*]}" ]; then

                echo -e "\e[33mOnly the CRC was manipulated\e[0m"

            else
                echo -e "\n\e[31mERROR: Other parts of the frame were also manipulated \e[0m"
                exit 1

            fi

        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck

}

# Function cut50PResCycle2:             Cut PRes in cycle 2 to a size of 50 Byte (+CRC+Preamble)
function cut50PResCycle2
{
    CUT_TYPE="PRes"
    CUT_CYCLE=2
    CUT_LENGTH=50
    echo -e "\n\e[36mTest $TEST_NR: Check Cut-task with a truncation to 50 Byte of second PRes\e[0m"
    cutFrame
}

# Function cutFrame:
#Predefined variables: CUT_TYPE for frame messageType; CUT_CYCLE for cycle; CUT_LENGTH for size
function cutFrame
{

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

    #Check frame data

    #Testcycle
    CYCLE=0
    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the manipulated one?
        if [ $TYPE_STIM == $CUT_TYPE -a $CYCLE == $CUT_CYCLE ]; then

            echo -e "\e[33mThis frame should be truncated to $CUT_LENGTH Byte\e[0m"

            #Add 12 Byte for Preamble and CRC
            CUT_LENGTH_NEW=$(($CUT_LENGTH+12))

            #Load frames
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Check truncated frame size
            if (( ${#FRAME_FM_A[*]} == $CUT_LENGTH_NEW )); then
                echo -e "\e[33mNew frame size is correct\e[0m"

            else
                echo -e "\n\e[31mERROR: Size ${#FRAME_FM_A[*]} is wrong. It should be $CUT_LENGTH_NEW \e[0m"
                exit 1

            fi


            #Remove CRC
            SIZE_MIN_CRC=$(($CUT_LENGTH_NEW-4))

            FRAME_STIM_A2=${FRAME_STIM_A[*]:0:$SIZE_MIN_CRC}
            FRAME_FM_A2=${FRAME_FM_A[*]:0:$SIZE_MIN_CRC}

            #Check the rest of the frame
            if [ "${FRAME_STIM_A2[*]}" == "${FRAME_FM_A2[*]}" ]; then

                echo -e "\e[33mThe data wasn't manipulated\e[0m"

            else
                echo -e "\n\e[31mERROR: The frame was also manipulated \e[0m"
                exit 1

            fi

        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck
}

# Function safetyRep2Start41Size11PResCycle3:   Safety Repetition of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
function safetyRep2Start41Size11PResCycle3
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=3
    PACK_NR=2
    PACK_START=41
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety packet Repetition-task with repeating two packets (Start 41, Size 11) beginning with PRes of cycle three\e[0m"
    safetyRepetition
}

# Function safetyRepetition:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK_SIZE size of the packets
function safetyRepetition
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

    #Check frame data

    #Testcycle
    CYCLE=0

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the start of the manipulation?
        if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE -ge $FRAME_CYCLE ]; then

            #Number of manipulated packet
            MAN_PACK_NR=$(($CYCLE-$FRAME_CYCLE+1))

            #Is current packet one of the cloned ones
            if (( $MAN_PACK_NR <= $PACK_NR )); then
                #clone

                #Cycle where the inserted safety packet is
                PACKET_CYCLE=$(($FRAME_CYCLE-1))

                echo -e "\e[33mThe safety packet of this frame should be a clone of cycle $PACKET_CYCLE \e[0m"
            else
                #Packet after clone

                #Cycle where the inserted safety packet is
                PACKET_CYCLE=$(($CYCLE-$PACK_NR))

                echo -e "\e[33mThe safety packet of this frame should be a stored packet of cycle $PACKET_CYCLE \e[0m"
            fi

            #Looking for the frame with the packet data

            CYCLE_P=0

            for ((NR_P=1 ; NR_P<=$NR_OF_FRAME; NR_P++))
            do

                #Load MessageType of stimulated frame and count up cycle at SoC
                MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR_P[$MESSAGE_TYPE]})

                case $MESSAGE_TYPE_STIM in
                01)
                    TYPE_STIM="SoC"
                    CYCLE_P=$(($CYCLE_P+1))
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


                if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE_P == $PACKET_CYCLE ]; then
                    echo -e "\e[33mThat is frame Nr $NR_P\e[0m"

                    #Load frames as array:
                    FRAME_STIM_A=($(eval "echo \${FRAME"$NR_P[*]}))
                    FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                    #Select packets
                    FRAME_STIM_P=${FRAME_STIM_A[*]:$PACK_START:$PACK_SIZE}
                    FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                    #Check the safety packet
                    if [ "${FRAME_STIM_P[*]}" == "${FRAME_FM_P[*]}" ]; then

                    echo -e "\e[33mThe exchanged safety packet is correct\e[0m"

                    else
                        echo -e "\n\e[31mERROR: The exchanged safety packet is wrong \e[0m"
                        exit 1

                    fi

                fi


            done

            #Load frames as array
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Select frame before packet
            FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PACK_START}
            FRAME_FM_1=${FRAME_FM_A[*]:0:$PACK_START}

            #Check the first part
            if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            #Select frame after packet

            #Byte after safety packet
            END_START=$(($PACK_START+$PACK_SIZE))

            #End of frame without CRC
            FRAME_END=$((${#FRAME_STIM_A[*]}-4))

            #Size of the last part
            END_SIZE=$(($FRAME_END-$END_START))

            FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
            FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

            #Check the last part
            if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            echo -e "\e[33mThe rest of the frame is correct\e[0m"


        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck
}

# Function safetyLoss2Start41Size11PResCycle3:   Safety Loss of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
function safetyLoss2Start41Size11PResCycle3
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=3
    PACK_NR=2
    PACK_START=41
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety packet Loss-task with removing two packets (Start 41, Size 11) beginning with PRes of cycle three\e[0m"
    safetyLoss
}

# Function safetyLoss:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK_SIZE size of the packets
function safetyLoss
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass

    #Create deleted frame packet
    FRAME_LOSS=
    for ((NR=1; NR<=$PACK_SIZE; NR++))
    do
        FRAME_LOSS="$FRAME_LOSS 00"
    done

    #remove first space
    FRAME_LOSS=${FRAME_LOSS:1}


    #Check frame data

    #Testcycle
    CYCLE=0

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the start of the manipulation?
        if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE -ge $FRAME_CYCLE ]; then


            #Number of manipulated packet
            MAN_PACK_NR=$(($CYCLE-$FRAME_CYCLE+1))

            #Is current packet a deleted one?
            if (( $MAN_PACK_NR <= $PACK_NR )); then
                #deleted packet
                echo -e "\e[33mThe safety packet of this frame should be removed \e[0m"

                #Load frames as array:
                FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
                FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                #Select packets
                FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                #Check the deleted packet
                if [ "$FRAME_FM_P" == "$FRAME_LOSS" ]; then

                    echo -e "\e[33mThe safety packet was removed\e[0m"

                else
                    echo -e "\n\e[31mERROR: There is still data of the selected packet \e[0m"
                    exit 1

                fi

                #check remaining of the data

                #Select frame before packet
                FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PACK_START}
                FRAME_FM_1=${FRAME_FM_A[*]:0:$PACK_START}

                #Check the first part
                if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                #Select frame after packet

                #Byte after safety packet
                END_START=$(($PACK_START+$PACK_SIZE))

                #End of frame without CRC
                FRAME_END=$((${#FRAME_STIM_A[*]}-4))

                #Size of the last part
                END_SIZE=$(($FRAME_END-$END_START))

                FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
                FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

                #Check the last part
                if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                echo -e "\e[33mThe rest of the frame is correct\e[0m"


            else
                #Packet not deleted

                FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
                FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

                #Compare frames
                if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                    echo "Outgoing frame $NR is the same"

                else
                    echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                    exit 1

                fi
            fi

        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck
}

# Function safetyInsertion2Start41Size11StartSn52PResCycle3:   Safety Insertion of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Second packet starts at 52. Start at PRes of Cycle 3
function safetyInsertion2Start41Size11StartSn52PResCycle3
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=3
    PACK_NR=2
    PACK_START=41
    PACK2_START=52
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety packet Insertion-task with exchanging data two packets (Start 41, Size 11) with the data of another packet (Start 52) beginning with PRes of cycle three\e[0m"
    safetyInsertion
}

# Function safetyInsertion:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK2_START start of second packet. PACK_SIZE size of the packets
function safetyInsertion
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))
    PACK2_START=$(($PACK2_START+8-1))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass


    #Check frame data

    #Testcycle
    CYCLE=0

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the start of the manipulation?
        if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE -ge $FRAME_CYCLE ]; then

            #Number of manipulated packet
            MAN_PACK_NR=$(($CYCLE-$FRAME_CYCLE+1))

            #Is current packet a deleted one?
            if (( $MAN_PACK_NR <= $PACK_NR )); then
                #deleted packet
                echo -e "\e[33mThe safety packet of this frame should be exchanged \e[0m"

                #Load frames as array:
                FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                #Select packet DUT
                FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                #Load the exchanged packet
                if (( $PACK2_START < $PACK_START )); then
                    #if other packet is sent before the DUT packet
                    echo -e "\e[33mThe other packet is sent before the DUT packet: The exchanged packet is in the same frame \e[0m"

                    FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))

                else
                    #other packet is sent after DUT packet: exchanged packet is from the last safety frame
                    PACK2_CYCLE=$(($CYCLE-1))
                    echo -e "\e[33mThe DUT packet is sent before the other packet: The exchanged packet was sent in the safety frame of cycle $PACK2_CYCLE \e[0m"

                    #Looking for the frame with the packet data

                    CYCLE_P=0

                    for ((NR_P=1 ; NR_P<=$NR_OF_FRAME; NR_P++))
                    do

                        #Load MessageType of stimulated frame and count up cycle at SoC
                        MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR_P[$MESSAGE_TYPE]})

                        case $MESSAGE_TYPE_STIM in
                        01)
                            TYPE_STIM="SoC"
                            CYCLE_P=$(($CYCLE_P+1))
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


                        if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE_P == $PACK2_CYCLE ]; then
                            echo -e "\e[33mThat is frame Nr $NR_P\e[0m"

                            #Load frames as array:
                            FRAME_STIM_A=($(eval "echo \${FRAME"$NR_P[*]}))

                        fi
                    done
                fi

                #select packet
                FRAME_STIM_P=${FRAME_STIM_A[*]:$PACK2_START:$PACK_SIZE}


                #Check the exchange of the packet
                if [ "$FRAME_FM_P" == "$FRAME_STIM_P" ]; then

                    echo -e "\e[33mThe safety packet was successfully exchanged\e[0m"

                else
                    echo -e "\n\e[31mERROR: The safety packet is wrong \e[0m"
                    exit 1

                fi

                #Load stimulation of current frame
                FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))

                #Select frame before packet
                FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PACK_START}
                FRAME_FM_1=${FRAME_FM_A[*]:0:$PACK_START}

                #Check the first part
                if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                #Select frame after packet

                #Byte after safety packet
                END_START=$(($PACK_START+$PACK_SIZE))

                #End of frame without CRC
                FRAME_END=$((${#FRAME_STIM_A[*]}-4))

                #Size of the last part
                END_SIZE=$(($FRAME_END-$END_START))

                FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
                FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

                #Check the last part
                if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                echo -e "\e[33mThe rest of the frame is correct\e[0m"


            else
                #Packet not deleted

                FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
                FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

                #Compare frames
                if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                    echo "Outgoing frame $NR is the same"

                else
                    echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                    exit 1

                fi
            fi

        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck
}

# Function safetyIncSeq2Start41Size11PResCycle4:                Safety Incorrect-Sequence of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 4
function safetyIncSeq2Start41Size11PResCycle4
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=4
    PACK_NR=2
    PACK_START=41
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety Incorrect-Sequence with switching two packets (Start 41, Size 11) beginning with PRes of cycle four\e[0m"
    safetyInc
}

# Function safetyInc:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK_SIZE size of the packets
function safetyInc
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass


    #Create deleted frame packet
    FRAME_LOSS=
    for ((NR=1; NR<=$PACK_SIZE; NR++))
    do
        FRAME_LOSS="$FRAME_LOSS 00"
    done

    #remove first space
    FRAME_LOSS=${FRAME_LOSS:1}


    #Check frame data

    #Testcycle
    CYCLE=0

    #Number of

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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


        if [  $TYPE_STIM == $FRAME_TYPE ]; then
            #safety frame

            #Check of the safety packets
            if [ $CYCLE -le $PACK_NR ]; then
                #deleted packet:
                echo -e "\e[33mThe safety packet of this frame should be removed \e[0m"

                #check packet

                #Load frames as array:
                FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                #Select packets
                FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                #Check the deleted packet
                if [ "$FRAME_FM_P" == "$FRAME_LOSS" ]; then

                    echo -e "\e[33mThe safety packet was removed\e[0m"

                else
                    echo -e "\n\e[31mERROR: There is still data of the selected packet \e[0m"
                    exit 1

                fi

            else
                #delayed or manipulated packets

                if [ $CYCLE -ge $FRAME_CYCLE -a $CYCLE -lt $(($FRAME_CYCLE+$PACK_NR)) ]; then
                    #manipulated
                    PACKET_CYCLE=$((2*$FRAME_CYCLE-$CYCLE-1))
                    echo -e "\e[33mThe safety packet of this frame should be the in reverse order delayed one of cycle $PACKET_CYCLE \e[0m"

                else
                    #delayed
                    PACKET_CYCLE=$(($CYCLE-$PACK_NR))
                    echo -e "\e[33mThe safety packet of this frame should be the delayed one of cycle $PACKET_CYCLE \e[0m"

                fi

                #Looking for the frame with the packet data

                CYCLE_P=0

                for ((NR_P=1 ; NR_P<=$NR_OF_FRAME; NR_P++))
                do

                    #Load MessageType of stimulated frame and count up cycle at SoC
                    MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR_P[$MESSAGE_TYPE]})

                    case $MESSAGE_TYPE_STIM in
                    01)
                        TYPE_STIM="SoC"
                        CYCLE_P=$(($CYCLE_P+1))
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


                    if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE_P == $PACKET_CYCLE ]; then
                        echo -e "\e[33mThat is frame Nr $NR_P\e[0m"

                        #Load frames as array:
                        FRAME_STIM_A=($(eval "echo \${FRAME"$NR_P[*]}))
                        FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                        #Select packets
                        FRAME_STIM_P=${FRAME_STIM_A[*]:$PACK_START:$PACK_SIZE}
                        FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                        #Check the safety packet
                        if [ "${FRAME_STIM_P[*]}" == "${FRAME_FM_P[*]}" ]; then

                        echo -e "\e[33mThe exchanged safety packet is correct\e[0m"

                        else
                            echo -e "\n\e[31mERROR: The exchanged safety packet is wrong \e[0m"
                            exit 1

                        fi

                    fi


                done

            fi

            #Check rest of frame data

            #Load frames as array
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Select frame before packet
            FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PACK_START}
            FRAME_FM_1=${FRAME_FM_A[*]:0:$PACK_START}

            #Check the first part
            if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            #Select frame after packet

            #Byte after safety packet
            END_START=$(($PACK_START+$PACK_SIZE))

            #End of frame without CRC
            FRAME_END=$((${#FRAME_STIM_A[*]}-4))

            #Size of the last part
            END_SIZE=$(($FRAME_END-$END_START))

            FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
            FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

            #Check the last part
            if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            echo -e "\e[33mThe rest of the frame is correct\e[0m"

        else
            #other frame

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi
    done

    #Check Jitter
    jitterCheck

}

# Function safetyIncData2Start41Size11PResCycle3:                Safety Incorrect-Data of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
function safetyIncData2Start41Size11PResCycle3
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=3
    PACK_NR=2
    PACK_START=41
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety Incorrect-Data with manipulating the payload of two packets (Start 41, Size 11) beginning with PRes of cycle three\e[0m"
    safetyData
}

# Function safetyData:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK_SIZE size of the packets
function safetyData
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))

    #Offset of manipulated Payload
    PAYLOAD_OFFSET=$(($PACK_START+$SAFETY_PAYLOAD))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass


    #Check frame data

    #Testcycle
    CYCLE=0

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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

        #Stimulated frame is the start of the manipulation?
        if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE -ge $FRAME_CYCLE ]; then


            #Number of manipulated packet
            MAN_PACK_NR=$(($CYCLE-$FRAME_CYCLE+1))

            #Is current packet a manipulated one?
            if (( $MAN_PACK_NR <= $PACK_NR )); then
                #deleted packet
                echo -e "\e[33mThe safety payload of this frame should be manipulated \e[0m"

                #Load frames as array:
                FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
                FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                #Select manipulated payload
                FRAME_FM_P=${FRAME_FM_A[PAYLOAD_OFFSET]}
                FRAME_STIM_P=${FRAME_STIM_A[PAYLOAD_OFFSET]}

                #Check the deleted packet
                if [ "$FRAME_FM_P" != "$FRAME_STIM_P" ]; then

                    echo -e "\e[33mThe payload was manipulated\e[0m"

                else
                    echo -e "\n\e[31mERROR: The payload wasn't manipulated \e[0m"
                    exit 1

                fi


                #check remaining of the data

                #Select frame before first payload Byte
                FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PAYLOAD_OFFSET}
                FRAME_FM_1=${FRAME_FM_A[*]:0:$PAYLOAD_OFFSET}

                #Check the first part
                if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                #Select frame after first payload Byte

                #Byte after manipulated payload
                END_START=$(($PAYLOAD_OFFSET+1))

                #End of frame without CRC
                FRAME_END=$((${#FRAME_STIM_A[*]}-4))

                #Size of the last part
                END_SIZE=$(($FRAME_END-$END_START))

                FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
                FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

                #Check the last part
                if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                    echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                    exit 1

                fi

                echo -e "\e[33mThe rest of the frame is correct\e[0m"


            else
                #Packet not deleted

                FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
                FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

                #Compare frames
                if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                    echo "Outgoing frame $NR is the same"

                else
                    echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                    exit 1

                fi
            fi

        else

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi

    done

    #Check Jitter
    jitterCheck
}

# Function safetyDelay2Start41Size11PResCycle3:                Safety Delay-task of 2 packets. The packet starts at Byte 41 and are 11 Bytes long. Start at PRes of Cycle 3
function safetyDelay2Start41Size11PResCycle3
{
    FRAME_TYPE="PRes"
    FRAME_CYCLE=3
    PACK_NR=2
    PACK_START=41
    PACK_SIZE=11
    echo -e "\n\e[36mTest $TEST_NR: Check safety Delay-task with delaying of two packets (Start 41, Size 11) beginning with PRes of cycle three\e[0m"
    safetyDelay
}

# Function safetyDelay:
#Predefined variables: FRAME_TYPE for frame messageType; FRAME_CYCLE for cycle; PACK_NR number of manipulated packets; PACK_START start Byte of the packet; PACK_SIZE size of the packets
function safetyDelay
{
    #Add Preamble to start (8) (-1 for start at entry 0)
    PACK_START=$(($PACK_START+8-1))

    #Check if the number of ingoing and outgoing frames is the same:
    allFramesPass


    #Create deleted frame packet
    FRAME_LOSS=
    for ((NR=1; NR<=$PACK_SIZE; NR++))
    do
        FRAME_LOSS="$FRAME_LOSS 00"
    done

    #remove first space
    FRAME_LOSS=${FRAME_LOSS:1}


    #Check frame data

    #Testcycle
    CYCLE=0

    #Number of

    for ((NR=1 ; NR<=$NR_OF_FRAME; NR++))
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


        if [  $TYPE_STIM == $FRAME_TYPE -a $CYCLE -ge $FRAME_CYCLE ]; then
            #safety frame

            #Check of the safety packets
            if [ $CYCLE -lt $(($FRAME_CYCLE+$PACK_NR)) ]; then
                #deleted packet:
                echo -e "\e[33mThe safety packet of this frame should be removed \e[0m"

                #check packet

                #Load frames as array:
                FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                #Select packets
                FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                #Check the deleted packet
                if [ "$FRAME_FM_P" == "$FRAME_LOSS" ]; then

                    echo -e "\e[33mThe safety packet was removed\e[0m"

                else
                    echo -e "\n\e[31mERROR: There is still data of the selected packet \e[0m"
                    exit 1

                fi

            else
                #delayed or manipulated packets

                PACKET_CYCLE=$(($CYCLE-$PACK_NR))
                echo -e "\e[33mThe safety packet of this frame should be the delayed one of cycle $PACKET_CYCLE \e[0m"

                #Looking for the frame with the packet data

                CYCLE_P=0

                for ((NR_P=1 ; NR_P<=$NR_OF_FRAME; NR_P++))
                do

                    #Load MessageType of stimulated frame and count up cycle at SoC
                    MESSAGE_TYPE_STIM=$(eval "echo \${FRAME"$NR_P[$MESSAGE_TYPE]})

                    case $MESSAGE_TYPE_STIM in
                    01)
                        TYPE_STIM="SoC"
                        CYCLE_P=$(($CYCLE_P+1))
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


                    if [ $TYPE_STIM == $FRAME_TYPE -a  $CYCLE_P == $PACKET_CYCLE ]; then
                        echo -e "\e[33mThat is frame Nr $NR_P\e[0m"

                        #Load frames as array:
                        FRAME_STIM_A=($(eval "echo \${FRAME"$NR_P[*]}))
                        FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

                        #Select packets
                        FRAME_STIM_P=${FRAME_STIM_A[*]:$PACK_START:$PACK_SIZE}
                        FRAME_FM_P=${FRAME_FM_A[*]:$PACK_START:$PACK_SIZE}

                        #Check the safety packet
                        if [ "${FRAME_STIM_P[*]}" == "${FRAME_FM_P[*]}" ]; then

                        echo -e "\e[33mThe exchanged safety packet is correct\e[0m"

                        else
                            echo -e "\n\e[31mERROR: The exchanged safety packet is wrong \e[0m"
                            exit 1

                        fi

                    fi


                done

            fi

            #Check rest of frame data

            #Load frames as array
            FRAME_STIM_A=($(eval "echo \${FRAME"$NR[*]}))
            FRAME_FM_A=($(eval "echo \${FM_FRAME"$NR[*]}))

            #Select frame before packet
            FRAME_STIM_1=${FRAME_STIM_A[*]:0:$PACK_START}
            FRAME_FM_1=${FRAME_FM_A[*]:0:$PACK_START}

            #Check the first part
            if [ "${FRAME_STIM_1[*]}" != "${FRAME_FM_1[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            #Select frame after packet

            #Byte after safety packet
            END_START=$(($PACK_START+$PACK_SIZE))

            #End of frame without CRC
            FRAME_END=$((${#FRAME_STIM_A[*]}-4))

            #Size of the last part
            END_SIZE=$(($FRAME_END-$END_START))

            FRAME_STIM_2=${FRAME_STIM_A[*]:$END_START:$END_SIZE}
            FRAME_FM_2=${FRAME_FM_A[*]:$END_START:$END_SIZE}

            #Check the last part
            if [ "${FRAME_STIM_2[*]}" != "${FRAME_FM_2[*]}" ]; then

                echo -e "\n\e[31mERROR: There is an error in the rest of the frame \e[0m"
                exit 1

            fi

            echo -e "\e[33mThe rest of the frame is correct\e[0m"

        else
            #other frame

            FRAME_STIM=$(eval "echo \${FRAME"$NR[*]})
            FRAME_FM=$(eval "echo \${FM_FRAME"$NR[*]})

            #Compare frames
            if [ "${FRAME_STIM[*]}" == "${FRAME_FM[*]}" ]; then
                echo "Outgoing frame $NR is the same"

            else
                echo -e "\n\e[31mERROR: Mismatch of outgoing frame $NR\e[0m"
                exit 1

            fi

        fi
    done

    #Check Jitter
    jitterCheck
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