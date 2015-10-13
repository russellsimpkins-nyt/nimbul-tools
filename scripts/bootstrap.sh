#!/bin/bash
# copied and pasted logic to sync from our platform-repo to local box
# https://nimbul-fe.prd.nytimes.com/clusters/1141/iam_credentials

path=$( dirname "${BASH_SOURCE[0]}" )
if [ -f ${path}/.aws_creds ]; then
    . "${path}/.aws_creds"
fi

if [[ "" == "${AWS_ACCESS_KEY_ID}" || "" == "${AWS_SECRET_ACCESS_KEY}" ]]; then
    echo "[ERROR] Missing AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY. You can add a ${path}/.aws_creds file to load the creds."
    exit 1
fi

if [ "" == "${TOKEN}" ]; then
    echo "[ERROR] Missing TOKEN. Set that in your env or add it to ${path}/.aws_creds"
    exit 1
fi
source ${path}/bootstrap-getopt.sh
if [ "${id}" == "" ]; then
    usage
fi

curl --header "Authorization: Token token=${TOKEN}" \
     -ik -XPUT https://nimbul-fe.prd.nytimes.com/api/v1/instances/${id}/bootstrap

