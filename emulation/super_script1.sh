#!/bin/bash

outdir=/home/clauz/results/random_seq_$(date +"%s")
mkdir -p $outdir

for i in $(seq 100); do
    outfile=${outdir}/output_${i}
    ./clearcaches.sh > $outfile 2>&1
    echo "-----" >> $outfile
    sleep 60 
    ./random_sequential_request.sh &
    sleep 2
    ./download_tests.sh >> $outfile 2>&1
    sleep 10
    killall random_sequential_request.sh
    echo "-----" >> $outfile
    ./clearcaches.sh >> $outfile 2>&1 
    sleep 40
done

