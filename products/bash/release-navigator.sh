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
# PARAMETERS:
#   -n : <namespace> (string), Defaults to "cp4i"
#   -r : <replicas> (string), Defaults to "1"
#
# USAGE:
#   With default values
#     ./release-navigator.sh
#
#   Overriding the namespace and number of replicas
#     ./release-navigator -n cp4i-prod -r 1

function usage() {
  echo "Usage: $0 -n <namespace> -r <replicas> -s <file storage>"
}

namespace="cp4i"
replicas="1"
storage="cp4i-file-performance-gid"

SCRIPT_DIR="$(dirname $0)"
source $SCRIPT_DIR/utils.sh
echo "Current Dir: $SCRIPT_DIR"

while getopts "n:r:s:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    replicas="$OPTARG"
    ;;
  s)
    storage="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

# Instantiate Platform Navigator
echo "INFO: Instantiating Platform Navigator"
YAML=$(cat <<EOF
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: ${namespace}-navigator
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-JTPV-KYG8TF
  replicas: ${replicas}
  version: 16.1.0
EOF
)
OCApplyYAML "$namespace" "$YAML"

# Waiting up to 20 minutes for platform navigator object to be ready
echo "INFO: Waiting up to 20 minutes for platform navigator object to be ready"
time=0

while [[ "$(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator -o json | jq -r '.status.conditions[] | select(.type=="Ready").status')" != "True" ]]; do
  if [ $time -gt 20 ]; then
    echo "INFO: The platform navigator object status:"
    echo "INFO: $(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator)"
    echo "ERROR: Exiting installation Platform Navigator object is not ready"
    exit 1
  fi
  echo "INFO: Waiting up to 20 minutes for platform navigator object to be ready. Waited ${time} minute(s)."

  time=$((time + 1))
  sleep 60
done

# Printing the platform navigator object status
echo "INFO: The platform navigator object status:"
echo "INFO: $(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator)"
echo "INFO: PLATFORM NAVIGATOR ROUTE IS: $(oc get route -n ${namespace} ${namespace}-navigator-pn -o json | jq -r .spec.host)"
