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
#   None
#
# USAGE:
#   ./setup-roks-iam.sh

# Get auth port with internal url and apply the operand config in common services namespace
IAM_Update_OperandConfig() {
  export EXTERNAL=$(oc get configmap cluster-info -n kube-system -o jsonpath='{.data.master_public_url}')
  export INT_URL="${EXTERNAL}/.well-known/oauth-authorization-server"
  export IAM_URL=$(curl $INT_URL 2>/dev/null | jq -r '.issuer')
  echo "INFO: External url: ${EXTERNAL}"
  echo "INFO: INT_URL: ${INT_URL}"
  echo "INFO: IAM URL : ${IAM_URL}"
  echo "INFO: Updating the OperandConfig 'common-service' for IAM Authentication"
  oc get OperandConfig -n ibm-common-services common-service -o json | jq '(.spec.services[] | select(.name == "ibm-iam-operator") | .spec.authentication)|={"config":{"roksEnabled":true,"roksURL":"'$IAM_URL'","roksUserPrefix":"IAM#"}}' | oc apply -f -
}

# Wait for up to 10 minutes for the OperandConfig to appear in the common services namespace for a ROKS cluster
time=0
until oc get OperandConfig -n ibm-common-services common-service ; do
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
