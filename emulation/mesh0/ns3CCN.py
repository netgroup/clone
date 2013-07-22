#!/usr/bin/python -i

# Copyright (c)2011-2013 the Boeing Company.
# See the LICENSE file included in this distribution.
#
# author: Jeff Ahrenholz <jeffrey.m.ahrenholz@boeing.com>
#
'''
ns3wifi.py - This script demonstrates using CORE with the ns-3 Wifi model.

How to run this:

    pushd ~/ns-allinone-3.16/ns-3.16
    sudo ./waf shell
    popd
    python -i ns3wifi.py

To run with the CORE GUI:

    pushd ~/ns-allinone-3.16/ns-3.16
    sudo ./waf shell
    cored
    
    # in another terminal
    cored -e ./ns3wifi.py
    # in a third terminal
    core
    # now select the running session

'''

import os, sys, time, optparse, datetime, math
try:
    from core import pycore 
except ImportError:
    # hack for Fedora autoconf that uses the following pythondir:
    if "/usr/lib/python2.6/site-packages" in sys.path:
        sys.path.append("/usr/local/lib/python2.6/site-packages")
    if "/usr/lib64/python2.6/site-packages" in sys.path:
        sys.path.append("/usr/local/lib64/python2.6/site-packages")
    if "/usr/lib/python2.7/site-packages" in sys.path:
        sys.path.append("/usr/local/lib/python2.7/site-packages")
    if "/usr/lib64/python2.7/site-packages" in sys.path:
        sys.path.append("/usr/local/lib64/python2.7/site-packages")
    from core import pycore

import ns.core
from core.misc import ipaddr 
from core.misc.ipaddr import MacAddr
from corens3.obj import Ns3Session, Ns3WifiNet, CoreNs3Net

# python interactive shell tab autocompletion
import rlcompleter, readline
readline.parse_and_bind('tab:complete')

def add_to_server(session):
    ''' Add this session to the server's list if this script is executed from
    the cored server.
    '''
    global server
    try:
        server.addsession(session)
        return True
    except NameError:
        return False

def wifisession(opt):
    ''' Run a test wifi session.
    '''
    #myservice = "Olsrd4Service"
    myservice = "CcnOlsrNS3Service"
    numWirelessNode=16;
    numWiredNode=0;
    ns.core.Config.SetDefault("ns3::WifiMacQueue::MaxPacketNumber",ns.core.UintegerValue(100)) 
    session = Ns3Session(persistent=True, duration=opt.duration)
    session.cfg['ccnx_dir']='/home/clauz/clone-git/ccnx/'
    session.cfg['olsr_dir']='/home/clauz/clone-git/olsrd-ccninfo/'
    session.cfg['rbn_dir']='/home/clauz/clone-git/routingbyname/'
    session.name = "ns3ccn"
    session.filename = session.name + ".py"
    session.node_count = str(numWirelessNode + numWiredNode + 1)
    session.services.importcustom("/home/clauz/.core/myservices")
    add_to_server(session)
    
    wifi = session.addobj(cls=Ns3WifiNet, name="wlan1", rate="OfdmRate54Mbps")
    wifi.setposition(150, 150, 0)
    wifi.phy.Set("RxGain", ns.core.DoubleValue(20.0))

    prefix = ipaddr.IPv4Prefix("10.0.0.0/16")
    
    def ourmacaddress(n):
        return MacAddr.fromstring("02:02:00:00:00:%02x" % n)
    
    nodes = []
    for i in range(4):
            for j in range(4):
                    k = 1 + i*4 + j
                    node = session.addnode(name = "n%d" % k)
                    node.newnetif(wifi, ["%s/%s" % (prefix.addr(k), prefix.prefixlen)], hwaddr=ourmacaddress(k))
                    session.services.addservicestonode(node, "router", myservice, verbose=True)
                    nodes.append(node)

    session.setupconstantmobility()

    for i in range(4):
            for j in range(4):
                    k = i*4 + j
                    nodes[k].setns3position(100 * j, 100 * i, 0)
                    nodes[k].setposition(100 * j, 100 * i, 0)

    #wifi.usecorepositions()
    # PHY tracing
    #wifi.phy.EnableAsciiAll("ns3wifi")
    
    session.thread = session.run(vis=False)
                    
    for node in nodes:
            session.services.bootnodeservices(node)
    
    return session
    
def main():
    ''' Main routine when running from command-line.
    '''
    usagestr = "usage: %prog [-h] [options] [args]"
    parser = optparse.OptionParser(usage = usagestr)
    parser.set_defaults(duration = 600, verbose = False)

    parser.add_option("-d", "--duration", dest = "duration", type = int,
                      help = "number of seconds to run the simulation")
    parser.add_option("-v", "--verbose", dest = "verbose",
                      action = "store_true", help = "be more verbose")

    def usage(msg = None, err = 0):
        sys.stdout.write("\n")
        if msg:
            sys.stdout.write(msg + "\n\n")
        parser.print_help()
        sys.exit(err)

    (opt, args) = parser.parse_args()


    for a in args:
        sys.stderr.write("ignoring command line argument: '%s'\n" % a)

    return wifisession(opt)


if __name__ == "__main__" or __name__ == "__builtin__":
    session = main()
    print "\nsession =", session
