#!/bin/bash

FROM_NODE="n5"
DECIMAL_DIGITS=14
MAXRAND=32767 #from man bash
N_FILES=30 #number of "mega1" files
PREFIX="ccnx:/mega1"
NUMLOOPS=4

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

corevcmd_getfile() {
	node=$1
	shift
    echo $@
	vcmd  -c /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/$node -- /usr/bin/env CCN_LOCAL_SOCKNAME=/tmp/.ccnd.${nodename}.sock CCND_KEYSTORE_DIRECTORY=/tmp/ccnd.keystore.${nodename} CCNX_DIR=/home/clauz/clone-git/ccnx/ /usr/bin/time -p /home/clauz/clone-git/ccnx/bin/ccngetfile -v $@
}

for j in $(seq 1 $NUMLOOPS); do
        thechosen1=$(choose_file_zipf)
        corevcmd_getfile ${FROM_NODE} ${PREFIX}/${thechosen1} /dev/null
        sleep 1
done


