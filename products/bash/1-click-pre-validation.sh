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
#   -r : <navReplicaCount> (string), Platform navigator replica count, Defaults to "3"
#   -n : <namespace> (string), Namespace for the 1-click validation. Defaults to "cp4i"
#
# USAGE:
#   With defaults values
#     ./1-click-pre-validation.sh 
#
#   Overriding the namespace and release-name
#     ./1-click-pre-validation.sh -n <namespace> -r <navReplicaCount>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <navReplicaCount>"
  divider
  exit 1
}

navReplicaCount="3"
CURRENT_DIR=$(dirname $0)
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
missingParams="false"
namespace="cp4i"
MIN_OCP_VERSION=4.12
MAX_OCP_VERSION=4.14

while getopts "p:r:n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    navReplicaCount="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${namespace// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation namespace is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ -z "${navReplicaCount// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation platform navigator replica count is empty. Please provide a value for '-r' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

divider
echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info Project name: $namespace"
echo -e "$info Platform navigator replica count: $navReplicaCount"
divider

export check=0


if [[ $(oc get node -o json | jq -r '.items[].metadata.labels["ibm-cloud.kubernetes.io/zone"]' | uniq | wc -l | xargs) != 1 ]]; then
  echo -e "$cross ERROR: This Software Catalog installer does not support multi-zone (MZR) clusters - see https://ibm.biz/cp4i-swcat-limitations for more details, or please try again with a cluster with all nodes in a single zone"
  check=1
else
  echo -e "$tick INFO: Cluster nodes are all in a single zone"
fi

if [[ $navReplicaCount -le 0 ]]; then
  echo -e "$cross ERROR: Platform navigator replica count should be greater than 0"
  check=1
else
  echo -e "$tick INFO: Platform navigator replica count ok"
fi

OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion')
OCP_MAJOR_VERSION=$(echo $OCP_VERSION | cut -f1 -d'.')
OCP_MINOR_VERSION=$(echo $OCP_VERSION | cut -f2 -d'.')
MIN_OCP_MAJOR_VERSION=$(echo $MIN_OCP_VERSION | cut -f1 -d'.')
MIN_OCP_MINOR_VERSION=$(echo $MIN_OCP_VERSION | cut -f2 -d'.')
MAX_OCP_MAJOR_VERSION=$(echo $MAX_OCP_VERSION | cut -f1 -d'.')
MAX_OCP_MINOR_VERSION=$(echo $MAX_OCP_VERSION | cut -f2 -d'.')
OCP_VERSION_OK=true
if [ "$OCP_MAJOR_VERSION" -lt "$MIN_OCP_MAJOR_VERSION" ] || ([ "$OCP_MAJOR_VERSION" -eq "$MIN_OCP_MAJOR_VERSION" ] && [ "$OCP_MINOR_VERSION" -lt "$MIN_OCP_MINOR_VERSION" ]); then
  echo -e "$cross ERROR: The Openshift version (${OCP_VERSION}) of the cluster is too low, ${MIN_OCP_VERSION} is the minimum currently supported"
  check=1
  OCP_VERSION_OK=false
fi
if [ "$OCP_MAJOR_VERSION" -gt "$MAX_OCP_MAJOR_VERSION" ] || ([ "$OCP_MAJOR_VERSION" -eq "$MAX_OCP_MAJOR_VERSION" ] && [ "$OCP_MINOR_VERSION" -gt "$MAX_OCP_MINOR_VERSION" ]); then
  echo -e "$cross ERROR: The Openshift version (${OCP_VERSION}) of the cluster is too high, ${MAX_OCP_VERSION} is the maximum currently supported"
  check=1
  OCP_VERSION_OK=false
fi
if [ "$OCP_VERSION_OK" == "true" ]; then
  echo -e "$tick INFO: The Openshift version (${OCP_VERSION}) is supported. Minimum version is ${MIN_OCP_VERSION} and maximum version is ${MAX_OCP_VERSION}"
fi

echo 'Output of "oc get nodes" for info:'
oc get nodes

divider

if [[ $check -ne 0 ]]; then
  echo -e "$cross ERROR: Rerun the installation after fixing the above validation errors (no need to delete the schematics workspace)."
  exit 1
else
  echo -e "$tick $all_done INFO: All validation checks passed $all_done $tick"
fi
