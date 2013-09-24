#!/bin/bash

process_one_line() {
    testfilename="$1"
    clearing=0
    declare -A clearings
    declare -A ccngettimes
    declare -A realtimes
    
    while read line; do
            case "$line" in
                    ccnx*) 
                            # ccnx:/tests/100k /dev/null
                            filename=$( echo $line | sed 's/^ccnx:\/tests\/\(.*\)/\1/' | cut -d ' ' -f 1 )
                            ;;
                    ccngetfile*)
                            # ccngetfile took: 13410ms
                            tmpvar=$( echo $line | awk '{print $NF}' )
                            ccngetfiletime=${tmpvar%ms}
                            ccngettimes[${filename}]=$ccngetfiletime
                            ;;
                    Retrieved*)
                            # Retrieved content /dev/null got 1048576 bytes.
                            filebytes=$( echo $line | awk '{print $(NF-1)}' )
                            ;;
                    real*)
                            # real 15.90
                            realtime=$( echo $line | awk '{print $2}' )
                            realtimes[${filename}]=$realtime
                            ;;
                    ----*)
                            clearing=1
                            ;;
                    clearing*)
                            [ clearing == 0 ] && continue
                            # clearing n10: marked stale: 1328
                            nodename=$( echo $line | tr ':' ' ' | awk '{print $2}' )
                            cocount=$( echo $line | awk '{print $NF}' )
                            clearings[${nodename}]=$cocount
                            ;;
                    marked*)
                            cocount=$( echo $line | awk '{print $NF}' )
                            clearings[${nodename}]=$cocount
                            ;;
            esac
    done < <( cat "$testfilename" )
    outstring1="$testfilename ; ${realtimes["100k"]} ; ${realtimes["1M"]} ; ${realtimes["2M"]} ; ${realtimes["test"]}"
    outstring2=""
    for i in $(seq 1 16); do
            n="n$i"
            outstring2="$outstring2 ; ${clearings[$n]}"
    done
    echo "$outstring1 $outstring2"
}

# header
echo "test name ; real 100k ; real 1M ; real 2M ; real test ; n1 ; n2 ; n3 ; n4 ; n5 ; n6 ; n7 ; n8 ; n9 ; n10 ; n11 ; n12 ; n13 ; n14 ; n15 ; n16"

for filename in $(ls); do
        process_one_line $filename 
done

