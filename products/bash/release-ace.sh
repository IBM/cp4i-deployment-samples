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
#   -r : <dashboard-release-name> (string), Defaults to "ace-dashboard-demo"
#   -e : <designer-release-name> (string), Defaults to "ace-designer-demo"
#
# USAGE:
#   With defaults values
#     ./release-ace.sh
#
#   Overriding the namespace and release-name
#     ./release-ace.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <dashboard-release-name> -e <designer-release-name>"
}

namespace="cp4i"
dashboard_release_name="ace-dashboard-demo"
designer_release_name="ace-designer-demo"

while getopts "n:r:e:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    dashboard_release_name="$OPTARG"
    ;;
  e)
    designer_release_name="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

# Ace Dashboard release
if ! ${CURRENT_DIR}/release-ace-dashboard.sh -n ${namespace} -r ${dashboard_release_name}; then
  echo "ERROR: Failed to release the ace dashboard in the namespace '$namespace'" 1>&2
  exit 1
fi

# Ace Designer release
if ! ${CURRENT_DIR}/release-ace-designer.sh -n ${namespace} -r ${designer_release_name}; then
  echo "ERROR: Failed to release the ace designer in the namespace '$namespace'" 1>&2
  exit 1
fi
