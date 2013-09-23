#!/bin/bash

NUMNODES=16
NUMFILES=30
N_FILES=$NUMFILES
PREFIX="ccnx:/mega1"
NUMLOOPS=120
DECIMAL_DIGITS=14
MAXRAND=32767 #from man bash

choose_file_zipf() {
        scaleup=$((10 ** $DECIMAL_DIGITS))
        x=$(($RANDOM * $scaleup / $MAXRAND))
        res=-1
        for i in $(seq 1 $(($N_FILES - 1))); do
                lowerbound=$(( $scaleup / 2 ** $i ))
                upperbound=$(( $scaleup / 2 ** ($i - 1) ))
                #echo $x $i $lowerbound $upperbound
                if [ $lowerbound -lt $x ] && [ $x -le $upperbound ]; then
                        res=$i
                        break;
                fi
        done
        [ $res -lt 0 ] && res=$N_FILES
        echo $res
}

corevcmd() {
	node=$1
	shift
	vcmd  -c /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/$node -- $@
}

for j in $(seq 1 $NUMLOOPS); do
        # select a random node
        selectednode=$(( 1 + $RANDOM % 16 ))
        while [ "$selectednode" == "4" ] || [ "$selectednode" == "16" ] || [ "$selectednode" == "5" ]; do
            selectednode=$(( 1 + $RANDOM % 16 ))
        done
        
        # select a zipf-random file
        i=$( choose_file_zipf )

        echo " ---> node: n${selectednode} download: ${PREFIX}/${i} "
        corevcmd n${selectednode} /usr/bin/env CCN_LOCAL_SOCKNAME=/tmp/.ccnd.${nodename}.sock CCND_KEYSTORE_DIRECTORY=/tmp/ccnd.keystore.${nodename} CCNX_DIR=/home/clauz/clone-git/ccnx/ /usr/bin/time /home/clauz/clone-git/ccnx/bin/ccngetfile -v ${PREFIX}/${i} /dev/null

        # random sleep
        sleepinterval=$(( 1 + $RANDOM % 2 ))
        echo "Sleeping $sleepinterval seconds..."
        sleep $sleepinterval
done

