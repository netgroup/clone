#!/bin/bash

OURCCNDIR=/home/clauz/clone-git/ccnx/
CCNPUTFILE=${OURCCNDIR}/bin/ccnputfile
CCNRM=${OURCCNDIR}/bin/ccnrm
FIND=/usr/bin/find
WGET=/usr/bin/wget

# print and execute a command
printandexec () {
		echo "$@"
		eval "$@"
}

# generate a new file that includes the HTTP header
addheadertoresource () {
		resource="$1"
		resourcesize=$( stat -c "%s" $resource)
		mimetype=$( file --mime-type $resource | awk '{print $2}' )
		tmpfile=$(tempfile -d /tmp/ -s ".wsaas")
		echo -e "HTTP/1.1 200 OK\r\nContent-Type: $mimetype\r\nContent-Length: $resourcesize\r\n\r\n" | cat - "$resource" > $tmpfile
		echo $tmpfile
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
printandexec $CCNRM ccnx:/
printandexec cd "${WEBSITE_DIR}/htdocs"
for resource in $( $FIND . -type f ); do
		resourcename=$( echo $resource | sed 's/^.\///' )
		resourcefullname="ccnx:/${domain}/${resourcename}"
		newresource=$( addheadertoresource $resource )
		printandexec $CCNPUTFILE -v -unversioned -local $resourcefullname $newresource
		# special case: index.html
		if [ "$resourcename" == "index.html" ]; then
				printandexec $CCNPUTFILE -v -unversioned -local ccnx:/${domain}/ $newresource
		fi
		#rm $newresource
done

# announce this domain through the OLSR CCNinfo plugin
$WGET -q -O - "http://127.0.0.1:2012/reg/add/${domain}" 2>/dev/null


