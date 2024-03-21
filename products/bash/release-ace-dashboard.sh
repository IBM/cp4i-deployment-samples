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


CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
dashboard_release_name="ace-dashboard-demo"
namespace="cp4i"
storage="ocs-storagecluster-cephfs"

function usage() {
  echo "Usage: $0 -n <namespace> -r <dashboard-release-name>"
}

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
  \?)
    usage
    exit
    ;;
  esac
done

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] ACE license: $(getACELicense $namespace)"

echo "INFO: Release ACE Dashboard..."
echo "INFO: Namespace: '$namespace'"
echo "INFO: Dashboard Release Name: '$dashboard_release_name'"

json=$(oc get configmap -n $namespace operator-info -o json 2> /dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

YAML=$(cat <<EOF
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
    license: $(getACELicense $namespace)
    use: CloudPakForIntegrationNonProduction
  displayMode: IntegrationRuntimes
  pod:
    containers:
      content-server:
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 50Mi
      control-ui:
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 125Mi
  replicas: 1
  storage:
    class: ${storage}
    size: 5Gi
    type: persistent-claim
  useCommonServices: true
  version: '12.0'
EOF
)
OCApplyYAML "$namespace" "$YAML"
