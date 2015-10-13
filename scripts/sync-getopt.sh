#!/bin/bash
GETOPT_COMPATIBLE=1
########################################################################
#
# This has our options for -esome  --env some -- type usage
########################################################################
usage() {
    echo "${0} required parameters"
    echo "-d --direction	: specify the sync direction up or down allowed"
    echo "-e --env    	: specify the environment"
    exit 1
}

# deal with getopt on mac osx
if [ -f /usr/local/opt/gnu-getopt/bin/getopt ]; then
    getopt=/usr/local/opt/gnu-getopt/bin/getopt
else
    getopt=getopt
fi

TEMP=$($getopt -o e:d: --long env:,direction: -n $0 -- "$@")
if [ $? -ne 0 ]; then
    echo "Parser problem. Make sure you have the right getopt installed."
    usage
fi

eval set -- "$TEMP"
# extract options and their arguments into variables.

while true ; do
    case "$1" in
        -d|--direction)
            direction=$2
            shift 2
            ;;
        -e|--env)
            env=$2
            shift 2
            ;;
        --) shift ; break ;;
        *) echo "Big fail. Check that getopt matches your case statement! $1 $2" ; exit 1 ;;
    esac
done


