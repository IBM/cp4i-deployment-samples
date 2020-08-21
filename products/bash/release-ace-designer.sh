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

function usage {
    echo "Usage: $0 -n <namespace> -r <designer_release_name>"
}

namespace="cp4i"
designer_release_name="ace-designer-demo"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) designer_release_name="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo "INFO: Release ACE Designer..."
echo "INFO: Namepace: '$namespace'"
echo "INFO: Designer Release Name: '$designer_release_name'"

cat << EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: DesignerAuthoring
metadata:
  name: ${designer_release_name}
  namespace: ${namespace}
spec:
  couchdb:
    storage:
      size: 10Gi
      type: persistent-claim
      class: ibmc-file-gold-gid
  designerFlowsOperationMode: local
  license:
    accept: true
    license: L-AMYG-BQ2E4U
    use: CloudPakForIntegrationNonProduction
  replicas: 1
  version: 11.0.0
  designerMappingAssist:
    enabled: true
EOF
