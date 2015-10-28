#!/bin/bash
# copied and pasted logic to sync from our platform-repo to local box
# https://nimbul-fe.prd.nytimes.com/clusters/1141/iam_credentials


path=$( dirname "${BASH_SOURCE[0]}" )

source ${path}/sync-getopt.sh

if [[ "$env" == "" || "$direction" =~ /(up|down)/ || "$team" == "" || "$app" == "" ]]; then
    echo "Missing required parameter(s) $direction $env"
    usage
    exit 1
fi

if [ -f "${path}/.aws_creds" ]; then
    source "${path}/.aws_creds"
fi

if [[ "" == "${AWS_ACCESS_KEY_ID}" || "" == "${AWS_SECRET_ACCESS_KEY}" ]]; then
    echo "[ERROR] Missing AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY. You can add a ${path}/.aws_creds file to load the creds."
    exit 1
fi

if [ ! -d "./remote/${team}/${env}" ]; then
    mkdir -p "./remote/${team}/${env}"
fi

if [ "${direction}"  == "up" ]; then

    # our platform repo does the job of updating the yum repo, which happens to live in the CI folder.
    # so, we can't sync with --delete
    if [ "${app}" == "ci" ]; then
        AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} aws s3 sync ./remote/${team}/${env}/${app}/ s3://infrastructure-deploy-nyt-net/${team}/${env}/${app}/
    else
        AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} aws s3 sync --delete ./remote/${team}/${env}/${app}/ s3://infrastructure-deploy-nyt-net/${team}/${env}/${app}/
    fi
else
    echo aws s3 sync s3://infrastructure-deploy-nyt-net/${team}/${env}/ ./remote/${team}/${env}/
    aws s3 sync s3://infrastructure-deploy-nyt-net/${team}/${env}/ ./remote/${team}/${env}/
fi
