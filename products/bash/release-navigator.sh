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
#   -r : <replicas> (string), Defaults to "3"
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
storage="ibmc-file-gold-gid"

SCRIPT_DIR="$(dirname $0)"
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
time=0
while ! cat <<EOF | oc apply -f -; do
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: ${namespace}-navigator
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-RJON-BZFQU2
  mqDashboard: true
  replicas: ${replicas}
  version: 2021.2.1
  storage:
    class: ibmc-file-gold-gid
EOF

  if [ $time -gt 10 ]; then
    echo "ERROR: Exiting installation as timeout waiting for PlatformNavigator to be created"
    exit 1
  fi
  echo "INFO: Waiting up to 10 minutes for PlatformNavigator to be created. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
done

# Waiting upto 90 minutes for platform navigator object to be ready
echo "INFO: Waiting upto 90 minutes for platform navigator object to be ready"
time=0

while [[ "$(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator -o json | jq -r '.status.conditions[] | select(.type=="Ready").status')" != "True" ]]; do
  echo "INFO: The platform navigator object status:"
  echo "INFO: $(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator)"
  if [ $time -gt 90 ]; then
    echo "ERROR: Exiting installation Platform Navigator object is not ready"
    exit 1
  fi
  echo "INFO: Waiting up to 90 minutes for platform navigator object to be ready. Waited ${time} minute(s)."

  time=$((time + 1))
  sleep 60
done

# Printing the platform navigator object status
echo "INFO: The platform navigator object status:"
echo "INFO: $(oc get PlatformNavigator -n ${namespace} ${namespace}-navigator)"
echo "INFO: PLATFORM NAVIGATOR ROUTE IS: $(oc get route -n ${namespace} ${namespace}-navigator-pn -o json | jq -r .spec.host)"
