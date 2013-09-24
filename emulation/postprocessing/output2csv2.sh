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
                            filename=$( echo $line | sed 's/^ccnx:\/(tests|mega1)\/\(.*\)/\1/' | cut -d ' ' -f 1 )
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
    outstring1="$testfilename"
    for fname in ${!ccngettimes[@]}; do
            outstring1="$outstring1 ; $fname ; ${ccngettimes[${fname}]}"
    done
    #outstring2=""
    #for i in $(seq 1 16); do
    #        n="n$i"
    #        outstring2="$outstring2 ; ${clearings[$n]}"
    #done
    echo "$outstring1"
}

# header
echo "test name ; filename1 ; ccngettime1; filename2 ; ccngettime2; filename3 ; ccngettime3; filename4 ; ccngettime4"

for filename in output_*; do
        process_one_line $filename 
done

