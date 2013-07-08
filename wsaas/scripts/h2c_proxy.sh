#!/bin/bash

if [ ! -p /tmp/fifo ]; then
		mknod /tmp/fifo p
fi

while [ 1 ]; do
		nc -l 8080 < /tmp/fifo | (
			while read line; do 
					URL=$(echo $line | grep 'GET' | awk '{print $2}')
					if [ -n "$URL" ]; then
							CCNXURL=$(echo $URL | sed 's/http:\//ccnx:/')
							ccngetfile ${CCNXURL} /tmp/out 2>&1 > /dev/null
							echo "HTTP/1.1 200"
							echo "Content-Type: application/octect-stream"
							echo ""
							cat /tmp/out
							killall nc #TODO: find a better way to close the connection
					fi
			done
		) > /tmp/fifo
done

