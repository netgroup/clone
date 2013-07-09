#!/bin/bash

CCNPUTFILE=/home/clauz/clone-git/ccnx/bin/ccnputfile
FIND=/usr/bin/find
WGET=/usr/bin/wget
WSAAS_INDEX_FILE=wsaas_index

# print and execute a command
printandexec () {
		echo "$@"
		eval "$@"
}

WEBSITE_DIR="$1"

if [ -z "$WEBSITE_DIR" ]; then
		echo "Usage: $0 <website directory>"
		exit 1
fi

# take the website name and other metadata from the config file
if ! [ -e "${WEBSITE_DIR}/wsaas.conf" ]; then
		echo "Error: missing ${WEBSITE_DIR}/wsaas.conf"
		exit 2
fi
source ${WEBSITE_DIR}/wsaas.conf
# now we should have the "domain" variable set
if [ -z "$domain" ]; then
		echo "Error in wsaas.conf. domain setting missing"
		exit 2
fi

# load each file in the website htdocs directory into the local ccnr
printandexec cd "${WEBSITE_DIR}/htdocs"
printandexec rm -f /tmp/${WSAAS_INDEX_FILE}
printandexec touch /tmp/${WSAAS_INDEX_FILE}
for resource in $( $FIND . -type f ); do
		resourcename=$( echo $resource | sed 's/^.\///' )
		resourcefullname="ccnx:/${domain}/${resourcename}"
		printandexec $CCNPUTFILE -v -unversioned -local $resourcefullname $resource
		# put the info in the index
		resourcesize=$( stat -c "%s" $resource)
		mimetype=$( file --mime-type $resource | awk '{print $2}' )
		echo "$resourcefullname $resourcesize $mimetype" >> /tmp/${WSAAS_INDEX_FILE}
		if [ "$resourcename" == "index.html" ]; then
				printandexec $CCNPUTFILE -v -unversioned -local ccnx:/${domain}/ $resource
				echo "ccnx:/${domain}/ $resourcesize $mimetype" >> /tmp/${WSAAS_INDEX_FILE}
		fi
done

printandexec $CCNPUTFILE -v -unversioned -local ccnx:/${domain}/${WSAAS_INDEX_FILE} /tmp/${WSAAS_INDEX_FILE}
#printandexec rm /tmp/${WSAAS_INDEX_FILE}

# announce this domain through the OLSR CCNinfo plugin
$WGET -q -O - "http://127.0.0.1:2012/reg/add/${domain}" 2>/dev/null


