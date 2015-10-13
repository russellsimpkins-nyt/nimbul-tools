#!/bin/bash
# copied and pasted logic to sync from our platform-repo to local box
# https://nimbul-fe.prd.nytimes.com/clusters/1141/iam_credentials


path=$( dirname "${BASH_SOURCE[0]}" )

source ${path}/sync-getopt.sh

if [[ "$env" == "" || "$direction" =~ /(up|down)/ ]]; then
    echo "Missing required parameter(s) $direction $env"
    usage
    exit 1
fi

if [ ! -d "./remote/du/${env}" ]; then
    mkdir -p "./remote/du/${env}"
fi

if [ "${direction}"  == "up" ]; then
    aws s3 sync ./remote/du/${env}/ s3://infrastructure-deploy-nyt-net/du/${env}/
else
    echo aws s3 sync s3://infrastructure-deploy-nyt-net/du/${env}/ ./remote/du/${env}/
    aws s3 sync s3://infrastructure-deploy-nyt-net/du/${env}/ ./remote/du/${env}/
fi
