#!/bin/bash

SERVICENAME="ccnolsrservice_start.sh"

corevcmd() {
	node=$1
	shift
	vcmd  -c /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/$node -- $@
}

for node in /tmp/$(ls -lt /tmp/ | grep pycore | head -n 1 | awk '{print $NF}')/*.pid; do
	nodename=$(basename $node .pid);
	#corevcmd $nodename chmod +x $SERVICENAME
    #corevcmd $nodename /usr/bin/screen -d -m -S service
    #corevcmd $nodename /usr/bin/screen -S service -X stuff \"\"./$SERVICENAME start\" `echo -ne '\015'`\"
    corevcmd $nodename bash $SERVICENAME start \; bash -i &
done

