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
#
# USAGE:
#   With defaults values
#     ./release-ace-dashboard.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-dashboard.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <dashboard-release-name>"
}

namespace="cp4i"
dashboard_release_name="ace-dashboard-demo"
storage="ibmc-file-gold-gid"
production="false"
while getopts "n:r:s:p" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    dashboard_release_name="$OPTARG"
    ;;
  s)
    storage="$OPTARG"
    ;;
  p)
    production="true"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo "INFO: Release ACE Dashboard..."
echo "INFO: Namespace: '$namespace'"
echo "INFO: Dashboard Release Name: '$dashboard_release_name'"

use="CloudPakForIntegrationNonProduction"

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  use="CloudPakForIntegrationProduction"

fi

json=$(oc get configmap -n $namespace operator-info -o json 2> /dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: Dashboard
metadata:
  name: ${dashboard_release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
  fi)
spec:
  license:
    accept: true
    license: L-APEH-BTHFYQ
    use: ${use}
  pod:
    containers:
      content-server:
        resources:
          limits:
            cpu: 250m
      control-ui:
        resources:
          limits:
            cpu: 250m
            memory: 250Mi
  replicas: 1
  storage:
    class: ${storage}
    size: 5Gi
    type: persistent-claim
  useCommonServices: true
  version: 11.0.0.10-r3-eus
EOF
