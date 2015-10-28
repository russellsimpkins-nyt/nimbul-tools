#!/bin/bash
GETOPT_COMPATIBLE=1
########################################################################
#
# This has our command line options
########################################################################
usage() {
    echo "${0} required parameters"
    echo "-d	: specify the sync direction up or down allowed"
    echo "-e    	: specify the environment"
    echo "-t	: specify the team"
    echo "-a :	specify the app"
    exit 1
}

TEMP=$(getopt a:e:d:t: $@)
if [ $? -ne 0 ]; then
    echo "Parser problem maybe."
    usage
fi

eval set -- "$TEMP"
# extract options and their arguments into variables.

while true ; do
    case "$1" in
        -a)
            app=$2
            shift 2
            ;;
        -d)
            direction=$2
            shift 2
            ;;
        -e)
            env=$2
            shift 2
            ;;
        -t)
            team=$2
            shift 2
            ;;
        --) shift ; break ;;
        *) echo "Big fail. Check that getopt matches your case statement! $1 $2" ; exit 1 ;;
    esac
done
