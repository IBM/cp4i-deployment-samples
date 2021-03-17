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
#   -n : <NAMESPACE> (string), defaults to "cp4i"
#
# USAGE:
#   With default values
#     ./license-helper.sh
#   Overriding namespace
#     ./license-helper.sh -n cp4i
#******************************************************************************

LICENSES_CM="demo-licenses"
NAMESPACE="cp4i"

function usage() {
  echo "Usage: $0 -n <NAMESPACE>"
}

while getopts "n:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

LICENSES=$(oc -n $NAMESPACE get configmap $LICENSES_CM -ojson 2> /dev/null)
echo "[DEBUG] Licenses configmap:"
echo $LICENSES

#------------------------------------------------ INSTALL JQ -----------------------------------------------------------

divider

echo -e "\nINFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
else
  jqInstalled=true
fi

if [[ !$jqInstalled ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  curl -o /tmp/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x /tmp/jq
fi

echo -e "\nINFO: Installed JQ version is $(/tmp/jq --version)"

function getAllLicenses() {
  echo $LICENSES | /tmp/jq -r '.data'
}

function getDemoLicense() {
  echo $LICENSES | tr '\r\n' ' ' | /tmp/jq -r '.data.demo'
}

function getACELicense() {
  echo $LICENSES | tr '\r\n' ' ' | /tmp/jq -r '.data.ace'
}

function getMQLicense() {
  echo $LICENSES | tr '\r\n' ' ' | /tmp/jq -r '.data.mq'
}
