#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), defaults to "cp4i"
#   -r : <release> (string), defaults to "ademo"
#   -d : <debug> (string), defaults to false
#
# USAGE:
#   With default values
#     ./get-apic-token.sh
#   Overriding environment, namespace, and release name, and enabling debug output
#     ./get-apic-token -n namespace -r release -d
#******************************************************************************

TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ACE_SECRET="ace-v11-service-creds"
APIC_SECRET="cp4i-admin-creds"
NAMESPACE="cp4i"
RELEASE="ademo"
DEBUG=false

function usage() {
  echo "Usage: $0 -n <namespace> -d"
}

OUTPUT=""
function handle_res() {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  else
    $DEBUG && echo -e "[ERROR] ${CROSS} Request failed: ${body}..."
    exit 1
  fi
}

while getopts "n:r:d" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  r)
    RELEASE="$OPTARG"
    ;;
  d)
    DEBUG=true
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

# Install jq
$DEBUG && echo "[DEBUG] Checking if jq is present..."
jqInstalled=false

if ! command -v jq &>/dev/null; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  $DEBUG && echo "[DEBUG] jq not found, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    $DEBUG && printf "on linux..."
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    JQ=./jq
    $DEBUG && echo "[DEBUG] ${TICK} jq installed"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    $DEBUG && printf "on macOS..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
    $DEBUG && echo "[DEBUG] ${TICK} jq installed"
  fi
fi

$DEBUG && echo "[DEBUG] jq version: $($JQ --version)"

# Gather info from cluster resources
$DEBUG && echo "[DEBUG] Gathering cluster info..."
PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
APIC_CREDENTIALS=$(oc get secret $APIC_SECRET -n $NAMESPACE -o json | $JQ .data)
$DEBUG && echo "[DEBUG] APIC_CREDENTIALS=${APIC_CREDENTIALS}"
API_MANAGER_USER=$(echo $APIC_CREDENTIALS | $JQ -r .username | base64 --decode)
$DEBUG && echo "[DEBUG] API_MANAGER_USER=${API_MANAGER_USER}"
API_MANAGER_PASS=$(echo $APIC_CREDENTIALS | $JQ -r .password | base64 --decode)
$DEBUG && echo "[DEBUG] API_MANAGER_PASS=${API_MANAGER_PASS}"
ACE_CREDENTIALS=$(oc get secret $ACE_SECRET -n $NAMESPACE -o json | $JQ .data)
$DEBUG && echo "[DEBUG] ACE_CREDENTIALS=${ACE_CREDENTIALS}"
ACE_CLIENT_ID=$(echo $ACE_CREDENTIALS | $JQ -r .client_id | base64 --decode)
$DEBUG && echo "[DEBUG] ACE_CLIENT_ID=${ACE_CLIENT_ID}"
ACE_CLIENT_SECRET=$(echo $ACE_CREDENTIALS | $JQ -r .client_secret | base64 --decode)
$DEBUG && echo "[DEBUG] ACE_CLIENT_SECRET=${ACE_CLIENT_SECRET}"

$DEBUG && echo "[DEBUG] Getting bearer token..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/token \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  -d "{
    \"username\": \"${API_MANAGER_USER}\",
    \"password\": \"${API_MANAGER_PASS}\",
    \"realm\": \"provider/default-idp-2\",
    \"client_id\": \"${ACE_CLIENT_ID}\",
    \"client_secret\": \"${ACE_CLIENT_SECRET}\",
    \"grant_type\": \"password\"
}")
handle_res "${RES}"
TOKEN=$(echo "${OUTPUT}" | $JQ -r ".access_token")
$DEBUG && echo "[DEBUG] Bearer token: ${TOKEN}"
$DEBUG && echo -e "[DEBUG] ${TICK} Got bearer token"
if [[ $TOKEN == "null" ]]; then
  echo -e "[ERROR] ${CROSS} Couldn't extract token"
  exit 1
else
  echo "${TOKEN}"
  exit 0
fi
