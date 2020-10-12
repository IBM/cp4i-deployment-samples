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



function usage {
    echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="tracing-demo"
block_storage="ibmc-block-gold"
file_storage="ibmc-file-gold-gid"
production="false"

echo "INFO: Tracing support currently disabled"
exit 0
while getopts "n:r:b:d:fp" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    b ) block_storage="$OPTARG"
      ;;
    f ) file_storage="$OPTARG"
      ;;
    p ) production="true"
      ;;
    \? ) usage; exit
      ;;
  esac
done




if [[ "$production" == "true" ]]
then
echo "Production Mode Enabled"

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
  env:
    - name: ENV_ResourceTemplateName
      value: production
  license:
    accept: true
  replicas:
    configDb: 3
    frontend: 3
    housekeepingWorker: 3
    jobWorker: 3
    master: 3
    scheduler: 3
    store: 3
  storage:
    configDbVolume:
      class: "${file_storage}"
    sharedVolume:
      class: "${file_storage}"
    tracingVolume:
      class: "${block_storage}"
      size: 150Gi
  version: 2020.3.1-0
EOF
else 
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
      class: "${file_storage}"
    sharedVolume:
      class: "${file_storage}"
    tracingVolume:
      class: "${block_storage}"
  version: 2020.3.1-0
EOF
fi

