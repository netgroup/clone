#!/bin/bash

#DEBUG=1 #true
DEBUG=0 #false
CCNDC=/home/clauz/clone-git/ccnx/bin/ccndc

declare -A FACE2DESTINATION
declare -A CURRENTFIB
declare -A IP2NEXTHOP
declare -A PREFIX2IP
declare -A PREFIX2NEXTHOP

# print and execute a command
printandexec () {
		echo "$@"
		eval "$@"
}

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
						destination=$( echo $line | grep -o "remote: [^ ]*" | awk '{print $2}' | cut -d ":" -f 1 )
						FACE2DESTINATION["$facenumber"]="$destination"
				fi
		elif (( $forwarding )); then
				if [ "${firstword:0:6}" != "ccnx:/" ]; then
						forwarding=0 #false
				else
						prefix="${firstword:6}"
						face=$(echo $line | grep -o "face: [^ ]*" | awk '{print $2}')
						# ignore "system" entries
						if [ "$face" != "0" ] && [ "${prefix:0:11}" != '%C1.M.FACE/' ]; then
								destination="${FACE2DESTINATION["$face"]}"
								CURRENTFIB["$prefix"]="$destination"
						fi
				fi
		elif [ "$firstword" == "Faces" ]; then
				faces=1 #true
		elif [ "$firstword" == "Forwarding" ]; then
				forwarding=1 #true
		fi
done < <( ccndstatus )

echo "------- FIB -----------"
for k in "${!CURRENTFIB[@]}"; do 
		echo "$k --> ${CURRENTFIB[$k]}"
done
echo "-----------------------"


# Read routes from olsrd txtinfo plug-in
while read line; do
	DESTINATION="$(echo $line | awk '{print $1}' | cut -d "/" -f 1 )"
	NEXTHOP="$(echo $line | awk '{print $2}')"
	IP2NEXTHOP["${DESTINATION}"]="$NEXTHOP"
done < <(wget http://127.0.0.1:2006/route -O - 2>/dev/null | grep -v "Table" | grep -v "Destination" | grep "...")

if (( $DEBUG )); then
		for k in "${!IP2NEXTHOP[@]}"; do 
				echo "$k --> ${IP2NEXTHOP[$k]}"
		done
fi

# Read names from olsrd CCNinfo plug-in
while read line; do
	NAME="$(echo $line | awk '{print $1}' | cut -d "/" -f 1 )"
	DESTINATION="$(echo $line | awk '{print $2}')"
	PREFIX2IP["${NAME}"]="$DESTINATION"
done < <(wget http://127.0.0.1:2012 -O - 2>/dev/null | grep -v "Name" | grep "...")

if (( $DEBUG )); then
		for k in "${!PREFIX2IP[@]}"; do 
				echo "$k --> ${PREFIX2IP[$k]}"
		done
fi

# Compute the PREFIX2NEXTHOP table to associate names to IP next hops
for key in "${!PREFIX2IP[@]}"; do 
		DESTINATION="${PREFIX2IP["$key"]}"
		PREFIX2NEXTHOP["$key"]="${IP2NEXTHOP[${DESTINATION}]}"
done

echo "-------- OLSR ---------"
for k in "${!PREFIX2NEXTHOP[@]}"; do 
		echo "$k --> ${PREFIX2NEXTHOP[$k]}"
done
echo "-----------------------"

# now synchronize the current CCN FIB with the PREFIX2NEXTHOP table computed from OLSR information
for prefix in "${!PREFIX2NEXTHOP[@]}"; do 
		fibnexthop="${CURRENTFIB["$prefix"]}"
		olsrnexthop="${PREFIX2NEXTHOP["$prefix"]}"
		if [ -z "$fibnexthop" ]; then
				# this prefix is not yet in the FIB. Add it
				printandexec $CCNDC add "ccnx:/${prefix}" udp ${olsrnexthop}
		elif [ "$fibnexthop" != "$olsrnexthop" ]; then
				# the next hop from OLSR is different from the one in the FIB. Update it
				printandexec $CCNDC add "ccnx:/${prefix}" udp ${olsrnexthop}
				printandexec $CCNDC del "ccnx:/${prefix}" udp ${fibnexthop}
		fi
done
for prefix in "${!CURRENTFIB[@]}"; do 
		fibnexthop="${CURRENTFIB["$prefix"]}"
		olsrnexthop="${PREFIX2NEXTHOP["$prefix"]}"
		if [ -z "$olsrnexthop" ]; then
				# this destination does not exist anymore. Remove it
				printandexec $CCNDC del "ccnx:/${prefix}" udp ${fibnexthop}
		fi
done



