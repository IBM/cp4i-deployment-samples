#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#   -t : <TKN-path> (string), Default to 'tkn'
#
#   With defaults values
#     ./post-load-test.sh
#
#   With overridden values
#     ./post-load-test.sh -n <NAMESPACE>

function divider() {
    echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
    echo "Usage: $0"
    divider
    exit 1
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
CURRENT_DIR=$(dirname $0)
missingParams="false"
NAMESPACE="cp4i"
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
BRANCH="main"

while getopts "n:" opt; do
    case ${opt} in
    n)
        NAMESPACE="$OPTARG"
        ;;
    \?)
        usage
        ;;
    esac
done

if [[ -z "${namespace// /}" ]]; then
    echo -e "$cross ERROR: Namespace parameter is empty. Please provide a value for '-n' parameter."
    usage
fi

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"
echo "INFO: Repo: '$REPO'"
echo "INFO: Branch: '$BRANCH'"
echo "INFO: TKN: '$TKN'"

API_BASE_URL=$(oc get secret -n $NAMESPACE eei-api-endpoint-client-id -o jsonpath='{.data.api}' | base64 --decode)
API_CLIENT_ID=$(oc get secret -n $NAMESPACE eei-api-endpoint-client-id -o jsonpath='{.data.cid}' | base64 --decode)

if [[ -z "${API_BASE_URL// /}" || -z "${API_CLIENT_ID// /}" ]]; then
    echo -e "$cross ERROR: Cold not get API Base URL and API Client ID. Check the secret 'eei-api-endpoint-client-id' in the '$NAMESPACE' namespace."
    exit 1
fi

SECONDS=0
for i in $(seq 1 50); do
    curl "${API_BASE_URL}/quote" -H "X-IBM-Client-Id: ${API_CLIENT_ID}" -k \
        -d $'{\n  "name": "Ronald McGee $i",\n  "email": "zarhuci@surguf.zm",\n  "age": 68221627,\n  "address": "408 Uneit Manor",\n  "usState": "CT",\n  "licensePlate": "hezihe",\n  "descriptionOfDamage": "56"\n}'
    midDuration=$SECONDS
    echo "$(($midDuration / 60)) minutes and $(($midDuration % 60)) seconds elapsed."
done
finalDuration=$SECONDS
echo "$(($finalDuration / 60)) minutes and $(($finalDuration % 60)) seconds elapsed."
