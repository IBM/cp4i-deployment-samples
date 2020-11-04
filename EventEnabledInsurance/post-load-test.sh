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
#   -n : <NAMESPACE> (string), Namespace in which the 1-click install was done in. Defaults to 'cp4i'
#   -c : <TARGET_POST_CALLS> (string), The total number of POST calls to be done via APIC. Defaults to '100'
#
#   With defaults values
#     ./post-load-test.sh
#
#   With overridden values
#     ./post-load-test.sh -n <NAMESPACE> -c <TARGET_POST_CALLS>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -c <TARGET_POST_CALLS>"
  divider
  exit 1
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
CURRENT_DIR=$(dirname $0)
NAMESPACE="cp4i"
TARGET_POST_CALLS=100
SUCCESSFUL_POST_CALLS=0
FAILED_POST_CALLS=0
MISSING_PARAMS="false"

while getopts "n:c:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  c)
    TARGET_POST_CALLS="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "\n$cross ERROR: Namespace parameter is empty. Please provide a value for '-n' parameter.\n"
  MISSING_PARAMS="true"
fi

if [[ -z "${TARGET_POST_CALLS// /}" ]]; then
  echo -e "\n$cross ERROR: Parameter for the total number of POST calls to be done via APIC. is empty. Please provide a value for '-c' parameter.\n"
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  usage
fi

CURRENT_DIR=$(dirname $0)
echo -e "\n$info INFO: Current directory: '$CURRENT_DIR'"
echo -e "$info INFO: Namespace: '$NAMESPACE'"
echo -e "$info INFO: Total POST calls to be done: '$TARGET_POST_CALLS'"

divider

API_BASE_URL=$(oc get secret -n $NAMESPACE eei-api-endpoint-client-id -o jsonpath='{.data.api}' | base64 --decode)
API_CLIENT_ID=$(oc get secret -n $NAMESPACE eei-api-endpoint-client-id -o jsonpath='{.data.cid}' | base64 --decode)

if [[ -z "${API_BASE_URL// /}" || -z "${API_CLIENT_ID// /}" ]]; then
  echo -e "\n$cross ERROR: Could not get API Base URL and API Client ID. Check the secret 'eei-api-endpoint-client-id' in the '$NAMESPACE' namespace."
  divider
  exit 1
fi

echo -e "$info INFO: Attempting $TARGET_POST_CALLS POST calls via APIC to perform a load test...\n"
SECONDS=0
for i in $(seq 1 $TARGET_POST_CALLS); do
  post_response=$(curl -s -w " %{http_code}" "${API_BASE_URL}/quote" -H "X-IBM-Client-Id: ${API_CLIENT_ID}" -k \
    -d $'{\n  "name": "Ronald McGee",\n  "email": "zarhuci@surguf.zm",\n  "age": 68221627,\n  "address": "408 Uneit Manor",\n  "usState": "CT",\n  "licensePlate": "hezihe",\n  "descriptionOfDamage": "56"\n}')
  post_response_code=$(echo "${post_response##* }")
  echo -e "$tick INFO: post response: ${post_response//200/}"
  if [ "$post_response_code" != "200" ]; then
    FAILED_POST_CALLS=$((FAILED_POST_CALLS + 1))
  else
    SUCCESSFUL_POST_CALLS=$((SUCCESSFUL_POST_CALLS + 1))
  fi
  echo -e "\n$info INFO: $SUCCESSFUL_POST_CALLS successful and $FAILED_POST_CALLS failed POST calls attempted in $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds."
  divider
done
FINAL_DURATION=$SECONDS
echo -e "$info INFO: $TARGET_POST_CALLS POST calls attempted via APIC and took $(($FINAL_DURATION / 60)) minutes and $(($FINAL_DURATION % 60)) seconds."
divider

if [[ "$FAILED_POST_CALLS" -gt 0 ]]; then
  echo -e "$cross ERROR: $FAILED_POST_CALLS POST calls via APIC have failed."
else
  echo -e "$tick INFO: Average number of POST calls per second attempted via APIC: $(($TARGET_POST_CALLS / $FINAL_DURATION))."
fi
