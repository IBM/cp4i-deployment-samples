#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE>"
  divider
  exit 1
}

set -e

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../products/bash/utils.sh

NAMESPACE="cp4i"

while getopts "n:" opt; do
  case ${opt} in
    n)
      NAMESPACE="$OPTARG"
      ;;
  \?)
    usage
    ;;
  esac
done

echo -e "$INFO [INFO] Create common tasks"
YAML=$(cat $CURRENT_DIR/../../CommonPipelineResources/cicd-tasks.yaml)
OCApplyYAML "$NAMESPACE" "$YAML"

echo -e "$INFO [INFO] Build command image"
