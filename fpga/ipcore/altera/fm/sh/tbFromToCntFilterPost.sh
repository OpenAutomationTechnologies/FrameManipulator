#!/bin/bash
# Post script to verify FromToCntFilter
# $ tbFromToCntFilterPost.sh [SETTINGS_FILE]

# Needed parameters of the setting file:
# GEN_FILE:     Output file of testbench
# G_FROM:       Generic gFrom: Lower limit
# G_TO:         Generic gTo: Upper limit

# The signal values of the output file from testbench (tbFromToCntFilter.vhd) are checked
# Format of testbench output file:
# Stimulation input iCnt | output value oCnt | Input data is between the limits oEn | Input Data beyond the limits oEnd

#Load settings file
SETTINGS_FILE=$1
source $SETTINGS_FILE

#Check file from testbench
if ! test -s $GEN_FILE
then
    echo "Output file is empty"
    exit 1

fi

echo -e "\nExecute simulation post-script:"

echo "Check generated file $GEN_FILE"

#check generated file
while read LINE;
do
    #Line to array
    ARRAY=($LINE)

    #Convert array to signals
    printf -v I_CNT "%d" 0x${ARRAY[0]}
    printf -v O_CNT "%d" 0x${ARRAY[1]}
    O_EN=${ARRAY[2]}
    O_END=${ARRAY[3]}


    #Check of signals:

    #Input signal is smaller as gFrom
    if (($I_CNT < $G_FROM)); then

        #oCnt=0
        if (($O_CNT != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oCnt should be 0, not $O_CNT"
            exit 1

        fi

        #oEn=0
        if (($O_EN != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEn should be 0, not $O_EN"
            exit 1

        fi

        #oEnd=0
        if (($O_END != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEnd should be 0, not $O_END"
            exit 1

        fi

        echo "Correct: $I_CNT $O_CNT $O_EN $O_END"

    #Input signal is bigger than gTo
    elif (($I_CNT > $G_TO)); then

        #oCnt=0
        if (($O_CNT != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oCnt should be 0, not $O_CNT"
            exit 1

        fi

        #oEn=0
        if (($O_EN != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEn should be 0, not $O_EN"
            exit 1

        fi

        #oEnd=1
        if (($O_END != 1)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEnd should be 1, not $O_END"
            exit 1

        fi

        echo "Correct: $I_CNT $O_CNT $O_EN $O_END"


    else


        #oCnt=iCnt-gFrom
        O_CNT_NEW=$((I_CNT-G_FROM))
        if (($O_CNT != $O_CNT_NEW)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oCnt should be $O_CNT_NEW, not $O_CNT"
            exit 1

        fi

        #oEn=1
        if (($O_EN != 1)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEn should be 1, not $O_EN"
            exit 1

        fi

        #oEnd=0
        if (($O_END != 0)); then

            echo "ERROR: $I_CNT $O_CNT $O_EN $O_END: oEnd should be 0, not $O_END"
            exit 1

        fi

        echo "Correct: $I_CNT $O_CNT $O_EN $O_END"

    fi


done < $GEN_FILE


exit 0