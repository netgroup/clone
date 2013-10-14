#!/bin/bash

#DEBUG=1 #true
DEBUG=0 #false
SHORTESTPATH=0
CCN_DIR=/home/clauz/clone-git/ccnx
NAMESFILE=HttpProxy.list
CCNDC="$CCN_DIR/bin/ccndc -t 3600"
CCNDSTATUS=$CCN_DIR/bin/ccndstatus
SLEEPINGTIME=10

# print and execute a command
printandexec () {
		echo "$@"
		eval "$@"
}

sortstring () {
		# sort a list of strings separated by space
		# also make these unique
		(
		for i in $1; do
				echo $i 
		done
		) | sort | uniq | tr "\\n" " " 
}

stripstring () {
		echo $1 | sed 's/\ $//' | sed 's/^\ //'
}

stripsort () {
		stripped=$( stripstring "$1" )
		sorted=$( sortstring "$stripped" )
		stripstring "$sorted"
}

isinstringlist () {
		needle="$1"
		haystack="$2"
		for h in $haystack; do
			if [ "$h" == "$needle" ]; then
				return 0 #true
			fi
		done
		return 1 #false
}

main () {
		# arrays holding info from CCN
		declare -A face2nexthop			# ccndstatus: face number --> nexthop
		declare -A CURRENTFIB			# ccndstatus: CCN prefix --> nexthop
		# arrays holding info from OLSR
		declare -A ip2nexthop			# txtinfo: IP destination --> nexthop
		declare -A ip2etx				# txtinfo: IP destination --> ETX
		declare -A PREFIX2NEXTHOPS		# CCN prefix --> nexthop
		declare -A PREFIX2DESTINATION	# CCN prefix --> destination (for shortest path only)

		# Get and parse the current CCN FIB
		faces=0 #false
		forwarding=0 #false
		while read line; do
				firstword="$(echo $line | awk '{print $1}')"
				if (( $faces )); then
						if [ "$firstword" != "face:" ]; then
								faces=0 #false
						else
								facenumber=$( echo $line | awk '{print $2}' )
								nexthop=$( echo $line | grep -o "remote: [^ ]*" | awk '{print $2}' | cut -d ":" -f 1 )
								face2nexthop["$facenumber"]="$nexthop"
						fi
				elif (( $forwarding )); then
						if [ "${firstword:0:5}" != "ccnx:" ]; then
								forwarding=0 #false
						else
								prefix="${firstword:5}"
								face=$(echo $line | grep -o "face: [^ ]*" | awk '{print $2}')
								# ignore "system" entries
								if [ "$face" != "0" ] && [ "${prefix:0:3}" != '/%C' ] && [ "${prefix:0:10}" != '/ccnx.org/' ]; then
										nexthop="${face2nexthop["$face"]}"
										# append the next hop
										CURRENTFIB["$prefix"]="${CURRENTFIB["$prefix"]} $nexthop"
								fi
						fi
				elif [ "$firstword" == "Faces" ]; then
						faces=1 #true
				elif [ "$firstword" == "Forwarding" ]; then
						forwarding=1 #true
				fi
		done < <( $CCNDSTATUS )

		# sort the lists of next hops
		for k in "${!CURRENTFIB[@]}"; do
				sortedlist=$( stripsort "${CURRENTFIB["$k"]}" )
				CURRENTFIB["$k"]="$sortedlist"
		done

		echo "------- FIB -----------"
		for k in "${!CURRENTFIB[@]}"; do
				echo "$k --> ${CURRENTFIB[$k]}"
		done
		echo "-----------------------"


		# Read routes from olsrd txtinfo plug-in
		while read line; do
			DESTINATION="$(echo $line | awk '{print $1}' | cut -d "/" -f 1 )"
			NEXTHOP="$(echo $line | awk '{print $2}')"
			ETX="$(echo $line | awk '{print $4}' | sed 's/\.//')"
			ip2nexthop["${DESTINATION}"]="$NEXTHOP"
			ip2etx["${DESTINATION}"]="$ETX"
		done < <(wget http://127.0.0.1:2006/route -O - 2>/dev/null | grep -v "Table" | grep -v "Destination" | grep "...")

		if (( $DEBUG )); then
				for k in "${!ip2nexthop[@]}"; do
						echo "$k --> ${ip2nexthop[$k]} ${ip2etx[$k]}"
				done
		fi

		# Read names from olsrd CCNinfo plug-in
		while read line; do
			NAME="$(echo $line | awk '{print $1}')"
			[ "${NAME:0:1}" != "/" ] && NAME="/${NAME}"
			DESTINATION="$(echo $line | awk '{print $2}')"
			LOCALLYORIGINATED="$(echo $line | awk '{print $3}')"
			# Compute the PREFIX2NEXTHOPS table to associate names to IP next hops
			if [ "$SHORTESTPATH" == 1 ]; then
				oldestination="${PREFIX2DESTINATION["$NAME"]}"
				if [ -z "$oldestination" ]; then
						PREFIX2NEXTHOPS["$NAME"]=${ip2nexthop["$DESTINATION"]}
						PREFIX2DESTINATION["$NAME"]="$DESTINATION"
				else
						[ $DEBUG == 1 ] && echo $DESTINATION "->" $oldestination ":" ${ip2etx["$DESTINATION"]} "-lt" ${ip2etx["$oldestination"]}
						if [ "$LOCALLYORIGINATED" == "Y" ]; then
								PREFIX2NEXTHOPS["$NAME"]="localhost"
								PREFIX2DESTINATION["$NAME"]="$DESTINATION"
						elif [ "${ip2etx["$DESTINATION"]}" -lt "${ip2etx["$oldestination"]}" ]; then
								PREFIX2NEXTHOPS["$NAME"]=${ip2nexthop["$DESTINATION"]}
								PREFIX2DESTINATION["$NAME"]="$DESTINATION"
						fi
				fi
			else
				if [ "$LOCALLYORIGINATED" == "Y" ]; then
						PREFIX2NEXTHOPS["$NAME"]="${PREFIX2NEXTHOPS["$NAME"]} localhost"
				else
						PREFIX2NEXTHOPS["$NAME"]="${PREFIX2NEXTHOPS["$NAME"]} ${ip2nexthop["$DESTINATION"]}"
				fi
			fi
		done < <(wget http://127.0.0.1:2012 -O - 2>/dev/null | grep -v "Name" | grep "...")

		# sort the lists of next hops
		for k in "${!PREFIX2NEXTHOPS[@]}"; do
				sortedlist=$( stripsort "${PREFIX2NEXTHOPS["$k"]}" )
				PREFIX2NEXTHOPS["$k"]="$sortedlist"
		done

		echo "-------- OLSR ---------"
		for k in "${!PREFIX2NEXTHOPS[@]}"; do
				echo "$k --> ${PREFIX2NEXTHOPS[$k]}"
		done
		echo "-----------------------"

		# now synchronize the current CCN FIB with the PREFIX2NEXTHOPS table computed from OLSR information
		for prefix in "${!PREFIX2NEXTHOPS[@]}"; do
				fibnexthops="${CURRENTFIB["$prefix"]}"
				olsrnexthops="${PREFIX2NEXTHOPS["$prefix"]}"
				if [ "$fibnexthops" != "$olsrnexthops" ]; then
						# convert the lists of nexthops into handy arrays
						declare -A ccnarray
						for i in $fibnexthops; do
								ccnarray["$i"]=1
						done
						declare -A olsrarray
						for i in $olsrnexthops; do
								olsrarray["$i"]=1
						done
						# add to the CCN fib the new nexthops
						for nh in "${!olsrarray[@]}"; do
								if [ -z "${ccnarray["$nh"]}" ] && ! isinstringlist "localhost" "$olsrnexthops"; then
										printandexec $CCNDC add "ccnx:${prefix}" udp ${nh}
								fi
						done
						# delete from the CCN fib the nexthops that aren't there anymore
						for nh in "${!ccnarray[@]}"; do
								if [ -z "${olsrarray["$nh"]}" ] || isinstringlist "localhost" "$olsrnexthops"; then
										printandexec $CCNDC del "ccnx:${prefix}" udp ${nh}
								fi
						done
						unset ccnarray
						unset olsrarray
				fi
		done
		for prefix in "${!CURRENTFIB[@]}"; do
				fibnexthops="${CURRENTFIB["$prefix"]}"
				olsrnexthops="${PREFIX2NEXTHOPS["$prefix"]}"
				if [ -z "$olsrnexthops" ]; then
						# this destination does not exist anymore. Remove it
						for nh in $fibnexthops; do
								printandexec $CCNDC del "ccnx:${prefix}" udp ${nh}
						done
				fi
		done
}

nameslist () {
		# write a list of domains announced in the networks and put it into a file
		tmpfile=$(tempfile -d /tmp/ -s ".wsaas")
		wget -q -O - "http://127.0.0.1:2012/" | egrep -o "http/[^[:space:]/]*" | sed 's/^.*http\/\(.*\)/\1/' > $tmpfile
		printandexec mv $tmpfile $NAMESFILE
}

while [ 1 ]; do
		main
		nameslist
		sleep $SLEEPINGTIME
done


