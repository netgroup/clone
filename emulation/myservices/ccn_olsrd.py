#
# vim:ts=4:expandtab
# CORE
# Copyright (c)2010-2012 the Boeing Company.
# See the LICENSE file included in this distribution.
#
''' CCNx user-defined service.
'''

import os

from core.service import CoreService, addservice
from core.misc.ipaddr import IPv4Prefix, IPv6Prefix

class CcnOlsrService(CoreService):
    ''' This is a CCNx user-defined service. 
    '''
    # a unique name is required, without spaces
    _name = "CcnOlsrService"
    # you can create your own group here
    _group = "Utility"
    # list of other services this service depends on
    _depends = ()
    # per-node directories
    #_dirs = ("/tmp/")
    _dirs = ()
    # generated files (without a full path this file goes in the node's dir,
    #  e.g. /tmp/pycore.12345/n1.conf/)
    _configs = ('ccnolsrservice_start.sh', 'ccnolsrservice_stop.sh', '.bashrc')
    # this controls the starting order vs other enabled services
    _startindex = 50
    # list of startup commands, also may be generated during startup
    _startup = ('/bin/bash ccnolsrservice_start.sh',)
    # list of shutdown commands
    _shutdown = ('/bin/bash ccnolsrservice_stop.sh',)

    _ipv4_routing = True
    _ipv6_routing = False

    @classmethod
    def generateconfig(cls, node, filename, services):
        ''' Return a string that will be written to filename, or sent to the
            GUI for user customization.
        '''
        try:
            ccnx_dir = node.session.cfg['ccnx_dir']
        except KeyError:
            # PLEASE SET THIS VALUE in your /etc/core/core.conf
            ccnx_dir = "/home/user/ccnx-git"
        try:
            olsr_dir = node.session.cfg['olsr_dir']
        except KeyError:
            # PLEASE SET THIS VALUE in your /etc/core/core.conf
            olsr_dir = "/home/user/olsrd-git"
        try:
            # routing by name script
            rbn_dir = node.session.cfg['rbn_dir']
        except KeyError:
            # PLEASE SET THIS VALUE in your /etc/core/core.conf
            rbn_dir = "/home/user/clone-git/routingbyname"


        cfg =  "#!/bin/bash\n"
        cfg += "# auto-generated by CCNOlsrService (ccn_olsrd.py)\n"

        if filename == cls._configs[0]: # start
                return cfg + cls.generateCcnOlsrConf(node, services, ccnx_dir, olsr_dir, rbn_dir, start=True)
        elif filename == cls._configs[1]: # stop
                return cfg + cls.generateCcnOlsrConf(node, services, ccnx_dir, olsr_dir, rbn_dir, start=False)
        elif filename == cls._configs[2]: # env
                return cls.generateCcnOlsrEnv(node, services, ccnx_dir, olsr_dir)
        else:
                raise ValueError
    
    @classmethod
    def generateCcnOlsrEnv(cls, node, services, ccnx_dir, olsr_dir):
            cfg = """
export CCNX_DIR=%s
export SHELL=/bin/bash
export HOME=$PWD
export PATH=$CCNX_DIR/bin:$PATH
export OLSRD_DIR=%s
export PATH=$OLSRD_DIR:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OLSRD_DIR/lib/ccninfo:$OLSRD_DIR/lib/txtinfo:$OLSRD_DIR/lib/jsoninfo
export CCN_LOCAL_SOCKNAME="/tmp/.ccnd.%s.sock"
export CCND_KEYSTORE_DIRECTORY="/tmp/ccnd.keystore.%s"
export CCND_LOG="/tmp/ccnd.%s.log"
export TERM=vt100
alias ls='ls --color'

4olsr () {
    wget -q http://127.0.0.1:2006/$1 -O -
}

""" % (ccnx_dir, olsr_dir, node.name, node.name, node.name)
            return cfg

    @classmethod
    def generateCcnOlsrConf(cls, node, services, ccnx_dir, olsr_dir, rbn_dir, start):
            cfg = """

export CCNX_DIR=%s
export OLSRD_DIR=%s
export CCN_LOCAL_SOCKNAME="/tmp/.ccnd.%s.sock"
export CCND_KEYSTORE_DIRECTORY="/tmp/ccnd.keystore.%s"
export CCND_LOG="/tmp/ccnd.%s.log"
export RBN_DIR=%s
export OLSR_INTERFACE="eth0"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OLSRD_DIR/lib/ccninfo:$OLSRD_DIR/lib/txtinfo:$OLSRD_DIR/lib/jsoninfo

printandexec() {
    echo "$@"
    eval "$@"
}

is_gateway () {
    if [ ${HOSTNAME:0:1} == "g" ]; then
        return 0   #true
    else
        return 1   #false
    fi
}

is_hna_node() {
    if ip address show | grep "10\.100\."; then
        return 0   #true
    else
        return 1   #false
    fi
}

olsrstart() {
    # we don't need no IPv6
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

    # take eth0's IP address and compute broadcast address
    ETH0_IP=$(ip -4 addr show dev ${OLSR_INTERFACE} | grep "inet " | awk '{print $2}' | cut -d "/" -f 1)
    ETH_MASK=$(ip -4 addr show dev ${OLSR_INTERFACE} | grep "inet " | awk '{print $2}' | cut -d "/" -f 2)
    # broadcast IP address (assuming /16 !!! FIXME!!!)
    BRD_IP=$(echo $ETH0_IP | awk 'BEGIN {FS="."} {print $1 "." $2 ".255.255"}')

    # take IP addresses and delete them from the interface
    printandexec ip addr del ${ETH0_IP}/${ETH_MASK} dev ${OLSR_INTERFACE}

    # add the broadcast address to eth0 (assuming /16 !!! FIXME !!!)
    printandexec ip addr add ${ETH0_IP}/16 brd ${BRD_IP} dev ${OLSR_INTERFACE}

    #generate an olsrd.conf on the fly
    cat - > olsrd.conf << EOF
LinkQualityFishEye  0

LoadPlugin "olsrd_txtinfo.so.0.1"
{
    PlParam      "accept" "0.0.0.0"
}

LoadPlugin "olsrd_jsoninfo.so.0.0"
{
    PlParam      "port" "9090"
    PlParam      "accept" "0.0.0.0"
}

LoadPlugin "olsrd_ccninfo.so.0.1"
{
    # port number the ccninfo plugin will be listening, default 2012
    PlParam     "port"   "2012"

    # ip address that can access the plugin, use "0.0.0.0"
    # to allow everyone
    PlParam     "Accept"   "127.0.0.1"

    # CCN message emission interval in seconds, default 5
    PlParam     "interval" "5" 

    # CCN message validity time in seconds, default 200
    PlParam     "vtime" "60"

    # sequence of names to be announced, a separate "name" parameter for each name
    #PlParam     "name"   "uniroma2.it"
    #PlParam     "name"   "wikipedia.org"
}

Interface "$OLSR_INTERFACE"
{
}

EOF

    if is_gateway; then
        # add a default Hna4 to olsrd.conf
        cat - >> olsrd.conf << EOF
Hna4
{
    0.0.0.0 0.0.0.0
}
EOF

        # and NAT
        # assume that the "internet interface" is eth1
        iptables -A POSTROUTING -t nat -o eth1 -j MASQUERADE
        #printandexec tc qdisc add dev eth1 parent root handle 1: htb default 1 
        #printandexec tc class add dev eth1 parent 1: classid 1:1 htb rate 1Mbit
    fi

    if is_hna_node ; then
        # announce the HNA
        HNA_NET=$( ip address show | grep "10\.100\." | cut -d "/" -f 1 | awk '{print $2}' | awk -F '.' '{print $1 "." $2 "." $3 "." 0}' )
        cat - >> olsrd.conf << EOF
Hna4
{
    ${HNA_NET} 255.255.255.0
}
EOF
    fi

    sleep 3
    # start olsrd
    printandexec ${OLSRD_DIR}/olsrd -f olsrd.conf -d 0
    sleep 2

}

ccnstart() {
    rm -vf $CCN_LOCAL_SOCKNAME
    rm -rvf $CCND_KEYSTORE_DIRECTORY
    mkdir -p $CCND_KEYSTORE_DIRECTORY
	$CCNX_DIR/bin/ccndstart
}

rbnstart() {
    # start the routing by name agent
    ln -sv $RBN_DIR/rbnagent.sh .
    ./rbnagent.sh >rbnagent.log 2>&1 &
}

start() {
    olsrstart
    ccnstart
    rbnstart
}

stop() {
	$CCNX_DIR/bin/ccndstop
}

""" % (ccnx_dir, olsr_dir, node.name, node.name, node.name, rbn_dir)
            if start:
                    cfg += "start\n"
            else:
                    cfg += "stop\n"
            return cfg



# this line is required to add the above class to the list of available services
addservice(CcnOlsrService)

