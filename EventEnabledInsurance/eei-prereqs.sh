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
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -r : <nav_replicas> (string), Defaults to '2'
#
#   With defaults values
#     ./eei-prereqs.sh
#
#   With overridden values
#     ./eei-prereqs.sh -n <namespace>

function usage {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"
echo "Namespace: $namespace"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Installing common prerequisites in the namespace '$namespace' for eei demo...\n"
if ! ${CURRENT_DIR}/../products/bash/common-prereqs.sh -n ${namespace}; then
  printf "$cross "
  echo "ERROR: Failed to install common-prereqs in the namespace '$namespace' for the eei demo"
  exit 1
else
  printf "$tick "
  echo "INFO: Successfuly installed common-prereqs in the namespace '$namespace' for the eei demo"
fi  #${CURRENT_DIR}/../../products/bash/common-prereqs.sh -n ${namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
