#!/bin/bash

outdir=/home/clauz/results/3in1_$(date +"%s")
mkdir -p $outdir

killemall() {
    sleep 10
    killall ccngetfile
    killall random_random_request.sh
    killall download_tests.sh
    killall random_zipf_request.sh
    sleep 15
    killall -9 ccngetfile
    killall -9 random_random_request.sh
    killall -9 download_tests.sh
    killall -9 random_zipf_request.sh
    sleep 5
}

for i in $(seq 30); do
    #baseline test
    echo "$(date) baseline $i"
    outfile=${outdir}/output_baseline_${i}
    ./clearcaches.sh > $outfile 2>&1
    echo "-----" >> $outfile
    sleep 10
    ./download_tests.sh >> $outfile 2>&1
    killemall
    echo "-----" >> $outfile
    ./clearcaches.sh >> $outfile 2>&1 
    sleep 150

    #random random interference
    echo "$(date) random random $i"
    outfile=${outdir}/output_random_random_${i}
    randoutfile=${outdir}/disturb_random_random_${i}
    ./clearcaches.sh > $outfile 2>&1
    echo "-----" >> $outfile
    sleep 10
    ./random_random_request.sh > $randoutfile 2>&1 &
    sleep 2
    ./download_tests.sh >> $outfile 2>&1
    killemall
    echo "-----" >> $outfile
    ./clearcaches.sh >> $outfile 2>&1 
    sleep 150

    #all random zipf choices
    echo "$(date) random zipf $i"
    outfile=${outdir}/output_random_zipf_mega1_${i}
    randoutfile=${outdir}/disturb_random_zipf_${i}
    ./clearcaches.sh > $outfile 2>&1
    echo "-----" >> $outfile
    sleep 10
    ./random_zipf_request.sh > $randoutfile 2>&1 &
    sleep 120
    ./download_mega1_zipf.sh >> $outfile 2>&1
    killemall
    echo "-----" >> $outfile
    ./clearcaches.sh >> $outfile 2>&1 
    sleep 150
done

