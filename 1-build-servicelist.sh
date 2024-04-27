#!/bin/bash

#####################
## Setup locations ##
#####################
location=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
logfile=$(mktemp --suffix=.servicelist.log)

echo "$(date +'%H:%M:%S') - INFO: Log file located at: $logfile"

########################################################
## Search for required commands and exit if not found ##
########################################################
commands=(sed grep column cat sort find rm wc iconv awk printf)

for i in ${commands[@]}; do
    if ! which $i &>/dev/null; then
        missingcommands="$i $missingcommands"
    fi
done
if [[ ! -z $missingcommands ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: The following commands are not found: $missingcommands"
    exit 1
fi

###########################
## Check path for spaces ##
###########################
if [[ $location == *" "* ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: The path contains spaces, please move the repository to a path without spaces!"
    exit 1
fi

style=$1


#############################
## Check if style is valid ##
#############################
if [[ ! $style = "srp" ]] && [[ ! $style = "snp" ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: Unknown style!"
    exit 1
fi

#####################
## Read index file ##
#####################
index=$(<"$location/build-source/$style.index")

##################################
## Enigma2 servicelist creation ##
##################################
if [[ -d $location/build-input/enigma2 ]]; then
    file=$location/build-output/servicelist-enigma2-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)
    lamedb=$(<"$location/build-input/enigma2/lamedb")
    channelcount=$(cat "$location/build-input/enigma2/"*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sort -u | wc -l)

    cat $location/build-input/enigma2/*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sed -e 's/#SERVICE //g' -e 's/.*/\U&\E/' -e 's/:/_/g' | sort -u | while read serviceref; do
        ((currentline++))
        if [[ $- == *i* ]]; then
            echo -ne "Enigma2: Converting channel: $currentline/$channelcount"\\r
        fi

        serviceref_id=$(sed -e 's/^[^_]*_0_[^_]*_//g' -e 's/_0_0_0$//g' <<<"$serviceref")
        unique_id=${serviceref_id%????}
        channelref=(${serviceref//_/ })
        channelname=$(grep -i -A1 "${channelref[3]}:.*${channelref[6]}:.*${channelref[4]}:.*${channelref[5]}:.*:.*" <<<"$lamedb" | sed -n "2p" | iconv -f utf-8 -t ascii//translit 2>>$logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/^//g')

        logo_srp=$(grep -i -m 1 "^$unique_id" <<<"$index" | sed -n -e 's/.*=//p')
        if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

        if [[ $style = "snp" ]]; then
            snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<<"$channelname")
            if [[ -z $snpname ]]; then snpname="--------"; fi
            logo_snp=$(grep -i -m 1 "^$snpname=" <<<"$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >>$tempfile
        else
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp" >>$tempfile
        fi
    done

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' >$file
    rm $tempfile
    echo "$(date +'%H:%M:%S') - INFO: Enigma2: Exported to $file"
else
    echo "$(date +'%H:%M:%S') - ERROR: Enigma2: $location/build-input/enigma2 not found"
fi

exit 0
