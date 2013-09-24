#!/bin/bash

SERVICENAME=/home/clauz/clone-git/emulation/initialize_ccnr_local.sh

corevcmd() {
	node=$1
	shift
	vcmd  -c /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/$node -- $@
}

corevcmd n4 bash $SERVICENAME \; bash -i &
sleep 10
corevcmd n16 bash $SERVICENAME \; bash -i &

