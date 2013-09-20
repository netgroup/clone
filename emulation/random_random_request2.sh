#!/bin/bash

NUMNODES=16
NUMFILES=4
PREFIX="ccnx:/tests"
NUMLOOPS=100

declare -A FILES
FILES[0]="100k"
FILES[1]="1M"
FILES[2]="2M"
FILES[3]="test"

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
        
        # select a random file
        i=$(( $RANDOM % $NUMFILES ))
        selectedfile="${PREFIX}/${FILES[$i]}"

        echo " ---> node: n${selectednode} download: $selectedfile"
        corevcmd n${selectednode} /usr/bin/env CCN_LOCAL_SOCKNAME=/tmp/.ccnd.${nodename}.sock CCND_KEYSTORE_DIRECTORY=/tmp/ccnd.keystore.${nodename} CCNX_DIR=/home/clauz/clone-git/ccnx/ /usr/bin/time /home/clauz/clone-git/ccnx/bin/ccngetfile -v $selectedfile /dev/null

        # random sleep
        sleepinterval=$(( 1 + $RANDOM % 2 ))
        echo "Sleeping $sleepinterval seconds..."
        sleep $sleepinterval
done

