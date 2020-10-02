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
#   -r : <release-name> (string), Defaults to "tracing-demo"
#   -b : <block-storage-class> (string), Default to "ibmc-block-gold"
#   -f : <file-storage-class> (string), Default to "ibmc-file-gold-gid"
#
# USAGE:
#   With defaults values
#     ./release-tracing.sh
#
#   Overriding the namespace and release-name
#     ./release-tracing -n cp4i-prod -r prod

echo "INFO: Tracing support currently disabled"
exit 0

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="tracing-demo"
block_storage="ibmc-block-gold"
file_storage="ibmc-file-gold-gid"

while getopts "n:r:b:d:f" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    b ) block_storage="$OPTARG"
      ;;
    f ) file_storage="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

cat << EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta2
kind: OperationsDashboard
metadata:
  namespace: "${namespace}"
  name: "${release_name}"
  labels:
    app.kubernetes.io/instance: ibm-integration-operations-dashboard
    app.kubernetes.io/managed-by: ibm-integration-operations-dashboard
    app.kubernetes.io/name: ibm-integration-operations-dashboard
spec:
  license:
    accept: true
  storage:
    configDbVolume:
      class: "${block_storage}"
    sharedVolume:
      class: "${block_storage}"
    tracingVolume:
      class: "${block_storage}"
  version: 2020.3.1-0
EOF
