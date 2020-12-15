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
#   -m : <metadata_name> (string)
#   -u : <metadata_uid> (string)
#
# USAGE:
#   With defaults values
#     ./release-ace-designer.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-designer.sh -n cp4i-prod -r prod
#
#   To add ownerReferences for the demos operator
#     ./release-ace-designer.sh -m metadata_name -u metadata_uid


function usage() {
  echo "Usage: $0 -n <namespace> -r <designer_release_name> -m <metadata_name> -u <metadata_uid>"
}

namespace="cp4i"
designer_release_name="ace-designer-demo"
storage="ibmc-block-gold"
while getopts "n:r:s:m:u:" opt; do
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
  m)
    metadata_name="$OPTARG"
    ;;
  u)
    metadata_uid="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done
echo "INFO: Release ACE Designer..."
echo "INFO: Namespace: '$namespace'"
echo "INFO: Designer Release Name: '$designer_release_name'"

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: DesignerAuthoring
metadata:
  name: ${designer_release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${metadata_uid} && ! -z ${metadata_name} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${metadata_name}
      uid: ${metadata_uid}"
  fi)
spec:
  couchdb:
    storage:
      size: 10Gi
      type: persistent-claim
      class: ${storage}
  designerFlowsOperationMode: local
  license:
    accept: true
    license: L-APEH-BPUCJK
    use: CloudPakForIntegrationNonProduction
  replicas: 1
  version: 11.0.0.10
  designerMappingAssist:
    enabled: true
EOF
