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
#   -e : <designer-release-name> (string), Defaults to "ace-designer-demo"
#
# USAGE:
#   With defaults values
#     ./release-ace-designer.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-designer.sh -n cp4i-prod -r prod

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
designer_release_name="ace-designer-demo"
namespace="cp4i"
storage="ocs-storagecluster-ceph-rbd"
file_storage="ocs-storagecluster-cephfs"

function usage() {
  echo "Usage: $0 -n <namespace> -r <designer_release_name>"
}

while getopts "n:r:s:f:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    designer_release_name="$OPTARG"
    ;;
  s)
    storage="$OPTARG"
    ;;
  f)
    file_storage="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] ACE license: $(getACELicense $namespace)"

echo "INFO: Release ACE Designer..."
echo "INFO: Namespace: '$namespace'"
echo "INFO: Designer Release Name: '$designer_release_name'"

json=$(oc get configmap -n $namespace operator-info -o json 2> /dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

YAML=$(cat <<EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: DesignerAuthoring
metadata:
  name: ${designer_release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
  fi)
spec:
  couchdb:
    replicas: 1
    storage:
      class: ${storage}
      size: 10Gi
      type: persistent-claim
  designerFlowsOperationMode: local
  designerMappingAssist:
    enabled: true
    incrementalLearning:
      schedule: "Every 15 days"
      useIncrementalLearning: true
      storage:
        type: persistent-claim
        class: ${file_storage}
  license:
    accept: true
    license: $(getACELicense $namespace)
    use: CloudPakForIntegrationNonProduction
  replicas: 1
  useCommonServices: true
  version: '12.0'
EOF
)
OCApplyYAML "$namespace" "$YAML"
