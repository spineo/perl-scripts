#!/bin/sh

# Main parameters
#
SCRIPT=get_quotes.pl

# Out file includes path (if not current)
#
OUT_FILE=quotes.txt
MAX_INDEX=0
QUOTES_URL=http://www.goodreads.com/quotes/tag/love?page=
ADDED_PARAMS=--quote-open '"quoteText">' --quote-close '<' --source-open "\"authorOrTitle\" [^>]+>" --source-close '<'

# Extract the command-line options
#
while [ $# -gt 1 ]; do
    key=$1

    case $key in
        -m|--max-index)
            MAX_INDEX=$2
            shift # past argument
        ;;
        *)
            MAX_INDEX=0
            QUOTES_URL=""
            shift
        ;;
    esac
    shift # past argument or value
done

# Remove the output file if it exists
#
if [ -f $OUT_FILE ]; then
    `rm $OUT_FILE`;
fi

# Page and run the script
#
if [ $MAX_INDEX > 1 ]; then
    for i in $(seq 1 $MAX_INDEX); do
        echo "Page=$i"
        quotes_url=$QUOTES_URL . $i
        `./$SCRIPT --url $quotes_url $ADDED_PARAMS >> $OUT_FILE`;
    done
fi
