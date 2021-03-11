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

function getAllLicenses() {
  echo $LICENSES | jq -r '.data'
}

function getDemoLicense() {
  echo $LICENSES | tr '\r\n' ' ' | jq -r '.data.demo'
}

function getACELicense() {
  echo $LICENSES | tr '\r\n' ' ' | jq -r '.data.ace'
}

function getMQLicense() {
  echo $LICENSES | tr '\r\n' ' ' | jq -r '.data.mq'
}
