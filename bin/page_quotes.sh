#!/bin/sh

# Main parameters
#
SCRIPT=get_quotes.pl

# Out file includes path (if not current)
#
OUT_FILE=./quotes.txt
MAX_INDEX=2
QUOTES_URL=https://www.goodreads.com/quotes/tag/love?page=
QUOTE_OPEN="\"quoteText\">"
QUOTE_CLOSE="<"
SOURCE_OPEN="\"authorOrTitle\">"
SOURCE_CLOSE="<"

# Parameters to export (site specific, as needed)
#
eval "export PERL_LWP_SSL_VERIFY_HOSTNAME=0"

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
    eval "rm $OUT_FILE"
fi
eval "touch $OUT_FILE"

# Page and run the script
#
if [ $MAX_INDEX > 1 ]; then
    #for i in $(seq 1 $MAX_INDEX); do
    i=1
    while [ "$i" != "$MAX_INDEX" ]; do 
        #echo "Page=$i"
        quotes_url="$QUOTES_URL$i"
        cmd="./$SCRIPT --url $quotes_url --quote-open '$QUOTE_OPEN' --quote-close '$QUOTE_CLOSE' --source-open '$SOURCE_OPEN' --source-close '$SOURCE_CLOSE' >> $OUT_FILE"
        echo "Running command: $cmd"
        eval $cmd
        i=$((i+1))
    done
fi
