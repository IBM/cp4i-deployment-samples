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
#     ./release-assetrepo.sh
#
#   Overriding the namespace and number of replicas
#     ./release-assetrepo -n cp4i-prod -r 1

function usage() {
  echo "Usage: $0 -n <namespace> -r <replicas> -s <file storage>"
}

namespace="cp4i"
replicas="1"
storage="cp4i-block-performance"

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

# Instantiate Asset repo
echo "INFO: Instantiating Asset repo"
YAML=$(cat <<EOF
apiVersion: integration.ibm.com/v1beta1
kind: AssetRepository
metadata:
  name: ${namespace}-assets
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-VTPK-22YZPK
  replicas: 1
  version: 2023.4.1
  singleReplicaOnly: true
  storage:
    assetDataVolume:
      class: ${storage}
    couchVolume:
      class: ${storage}
EOF
)
OCApplyYAML "$namespace" "$YAML"

# Waiting up to 20 minutes for AssetRepo object to be ready
echo "INFO: Waiting up to 20 minutes for AssetRepo object to be ready"
time=0

while [[ "$(oc get AssetRepository -n ${namespace} ${namespace}-assets -o json | jq -r '.status.conditions[] | select(.type=="Ready").status')" != "True" ]]; do
  if [ $time -gt 20 ]; then
    echo "INFO: The asset repo object status:"
    echo "INFO: $(oc get AssetRepository -n ${namespace} ${namespace}-assets)"
    echo "ERROR: Exiting installation Asset Repo object is not ready"
    exit 1
  fi
  echo "INFO: Waiting up to 20 minutes for asset repo object to be ready. Waited ${time} minute(s)."

  time=$((time + 1))
  sleep 60
done

# Printing the asset repo object status
echo "INFO: The asset repo object status:"
echo "INFO: $(oc get AssetRepository -n ${namespace} ${namespace}-assets)"