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
#   ./setup-roks-iam.sh

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


# Get auth port with internal url and apply the operand config in common services namespace
IAM_Update_OperandConfig() {
  export EXTERNAL=$(oc get configmap cluster-info -n kube-system -o jsonpath='{.data.master_public_url}')
  export INT_URL="${EXTERNAL}/.well-known/oauth-authorization-server"
  export IAM_URL=$(curl $INT_URL 2>/dev/null | jq -r '.issuer')
  echo "INFO: External url: ${EXTERNAL}"
  echo "INFO: INT_URL: ${INT_URL}"
  echo "INFO: IAM URL : ${IAM_URL}"
  echo "INFO: Updating the OperandConfig 'common-services' for IAM Authentication"
  time=0
  until oc get OperandConfig -n $namespace common-service -o json | jq '(.spec.services[] | select(.name == "ibm-iam-operator") | .spec.authentication)|={"config":{"roksEnabled":true,"roksURL":"'$IAM_URL'","roksUserPrefix":"IAM#"}}' | oc apply -f - ; do
    if [ $time -gt 10 ]; then
      echo "ERROR: Exiting installation as timeout waiting to update the OperandConfig 'common-services' for IAM Authentication"
      exit 1
    fi
    echo "INFO: Waiting up to 10 minutes to update the OperandConfig 'common-services' for IAM Authentication"
    time=$((time + 1))
    sleep 60
  done
  echo "INFO: OperandConfig 'common-services' for IAM Authentication updated successfully"
}

# Wait for up to 10 minutes for the OperandConfig to appear in the common services namespace for a ROKS cluster
time=0
until oc get OperandConfig -n $namespace common-service ; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Exiting installation as OperandConfig 'common-service' is not found'"
    exit 1
  fi
  echo "INFO: Waiting up to 10 minutes for OperandConfig 'common-service' to be available. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
done
echo "INFO: Operand config 'common-service' found, proceeding with updating the OperandConfig to enable Openshift Authentication..."
IAM_Update_OperandConfig
