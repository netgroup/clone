#!/bin/bash

WSAAS_INDEX_FILE=wsaas_index

if [ ! -p /tmp/nc_fifo ]; then
		mknod /tmp/nc_fifo p
fi

getfileindex() {
		# retrieve the file index
		domain=$( echo $1 | awk -F / '{print $2}' )
		if [ ! -e ~/.h2c_proxy/${domain}/${WSAAS_INDEX_FILE} ]; then
				echo "Create dir ~/.h2c_proxy/${domain}" 1>&2
				mkdir -p ~/.h2c_proxy/${domain}
				ccngetfile -unversioned ccnx:/${domain}/${WSAAS_INDEX_FILE} ~/.h2c_proxy/${domain}/${WSAAS_INDEX_FILE}
		fi
}

getresourceline() {
		domain="$2"
		grep -F "$1 " ~/.h2c_proxy/${domain}/${WSAAS_INDEX_FILE}
}

findsize() {
		# find the size of a given file inside the index
		getfileindex $1
		domain=$( echo $1 | awk -F / '{print $2}' )
		resourceline=$( getresourceline "$1" "$domain" )
		if [ -n "$resourceline" ]; then
				echo $resourceline | awk '{print $2}'
		fi
}

findmimetype() {
		# find the mime type of a given file inside the index
		getfileindex $1
		domain=$( echo $1 | awk -F / '{print $2}' )
		resourceline=$( getresourceline "$1" "$domain" )
		if [ -n "$resourceline" ]; then
				echo $resourceline | awk '{print $3}'
		fi
}

while [ 1 ]; do
		exec 3<>/tmp/nc_fifo
		echo "spawn nc" 1>&2
		nc -l 8080 <&3 | (
			while read line; do 
					URL=$(echo $line | grep 'GET' | awk '{print $2}')
					if [ -n "$URL" ]; then
							echo "Requested: $URL" 1>&2
							CCNXURL=$(echo $URL | sed 's/http:\//ccnx:/')
							echo "HTTP/1.1 200" | tee /dev/stderr
							echo "Content-Type:" $( findmimetype $CCNXURL ) | tee /dev/stderr
							echo "Content-Length:" $( findsize $CCNXURL ) | tee /dev/stderr
							echo ""
							echo "Retrieving $CCNXURL" 1>&2
							ccngetfile -unversioned ${CCNXURL} /dev/stdout 
							exec 3>&-
							exec 3<&-
					fi
			done
		) >&3
done

