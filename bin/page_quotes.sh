#!/bin/sh

SCRIPT=get_quotes.pl
OUT_FILE=quotes.txt
MAX_INDEX=1

while [ $# -gt 1 ]; do
    key=$1

    case $key in
        -u|--quotes-url)
            QUOTES_URL="$2"
            shift
        ;;
        -m|--max-index)
            MAX_INDEX=$2
            shift # past argument
        ;;
        *)
            MAX_INDEX=1
            QUOTES_URL=""
            shift
        ;;
    esac
    shift # past argument or value
done

if [[ ($MAX_INDEX > 1) && (! -z $QUOTES_URL) ]]; then
    for i in $(seq 1 $MAX_INDEX); do
        echo $i
    done
fi
