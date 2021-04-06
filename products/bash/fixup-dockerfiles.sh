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
#
# USAGE:
#   With defaults values
#     ./fixup-dockerfiles.sh
#
#   Overriding the namespace
#     ./fixup-dockerfiles.sh -n cp4i-prod

function usage() {
  echo "Usage: $0 -n <namespace>"
}

namespace="cp4i"

while getopts "n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

SCRIPT_DIR=$(dirname $0)

echo -e "\nINFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
  JQ=./jq
else
  jqInstalled=true
  JQ=jq
fi

if [[ "$jqInstalled" == "false" ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "INFO: Installing on linux"
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "INFO: Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
    JQ=jq
  fi
fi

echo -e "\nINFO: Installed JQ version is $($JQ --version)"

# Check if the ibm-entitlement-key secret includes the staging ER
STAGING_AUTHS=$(oc get secret --namespace ${namespace} ibm-entitlement-key -o json | $JQ -r '.data.".dockerconfigjson"' | base64 --decode | $JQ -r '.auths["cp.stg.icr.io"]')
if [[ "$STAGING_AUTHS" == "" || "$STAGING_AUTHS" == "null" ]]; then
  echo "Using production images for dockerfiles"
  exit 0
fi

SCRIPT_DIR="$(dirname $0)"

DOCKERFILES="$SCRIPT_DIR/../../DrivewayDentDeletion/Operators/Dockerfiles/* $SCRIPT_DIR/../../EventEnabledInsurance/ACE/*.Dockerfile $SCRIPT_DIR/../../EventEnabledInsurance/MQ/Dockerfile"
for DOCKERFILE in $DOCKERFILES; do
  echo $DOCKERFILE
  sed -i -e "s/cp.icr.io/cp.stg.icr.io/g" $DOCKERFILE
  rm -rf ${DOCKERFILE}-e
done
