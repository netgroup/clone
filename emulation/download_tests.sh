#!/bin/bash

FROM_NODE="n5"

corevcmd_getfile() {
	node=$1
	shift
    echo $@
	vcmd  -c /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/$node -- /usr/bin/env CCN_LOCAL_SOCKNAME=/tmp/.ccnd.${nodename}.sock CCND_KEYSTORE_DIRECTORY=/tmp/ccnd.keystore.${nodename} CCNX_DIR=/home/clauz/clone-git/ccnx/ /usr/bin/time -p /home/clauz/clone-git/ccnx/bin/ccngetfile -v $@
}

corevcmd_getfile ${FROM_NODE} ccnx:/tests/100k /dev/null
sleep 5
corevcmd_getfile ${FROM_NODE} ccnx:/tests/1M /dev/null
sleep 5
corevcmd_getfile ${FROM_NODE} ccnx:/tests/2M /dev/null
sleep 5
corevcmd_getfile ${FROM_NODE} ccnx:/tests/test /dev/null

