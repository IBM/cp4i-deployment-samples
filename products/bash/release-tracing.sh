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

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="tracing-demo"
block_storage="ibmc-block-gold"
file_storage="ibmc-file-gold-gid"
production="false"
CURRENT_DIR=$(dirname $0)

while getopts "n:r:b:d:f:p" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  b)
    block_storage="$OPTARG"
    ;;
  f)
    file_storage="$OPTARG"
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

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] Tracing license: $(getTracingLicense $namespace)"

json=$(oc get configmap -n $namespace operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta2
kind: OperationsDashboard
metadata:
  namespace: "${namespace}"
  name: "${release_name}"
  labels:
    app.kubernetes.io/instance: ibm-integration-operations-dashboard
    app.kubernetes.io/managed-by: ibm-integration-operations-dashboard
    app.kubernetes.io/name: ibm-integration-operations-dashboard
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
    echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
  fi)
spec:
  env:
    - name: ENV_ResourceTemplateName
      value: production
  license:
    accept: true
    license: $(getTracingLicense $namespace)
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
  version: 2021.2.1-0
EOF
else
  cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta2
kind: OperationsDashboard
metadata:
  namespace: "${namespace}"
  name: "${release_name}"
  labels:
    app.kubernetes.io/instance: ibm-integration-operations-dashboard
    app.kubernetes.io/managed-by: ibm-integration-operations-dashboard
    app.kubernetes.io/name: ibm-integration-operations-dashboard
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
    license: $(getTracingLicense $namespace)
  storage:
    configDbVolume:
      class: "${file_storage}"
    sharedVolume:
      class: "${file_storage}"
    tracingVolume:
      class: "${block_storage}"
  version: 2021.2.1-0
EOF
fi

# If the icp4i-od-store-cred then create a dummy one that the service binding will populate
oc create secret generic -n ${namespace} icp4i-od-store-cred --from-literal=icp4i-od-cacert.pem="empty" --from-literal=username="empty" --from-literal=password="empty" --from-literal=tracingUrl="empty"

echo "Waiting for Operations Dashboard installation to complete..."
for i in $(seq 1 400); do
  STATUS=$(oc get OperationsDashboard -n ${namespace} ${release_name} -o jsonpath='{.status.phase}')
  if [ "$STATUS" == "Ready" ]; then
    printf "$tick"
    echo "Operations Dashboard is ready"
    break
  else
    echo "Waiting for Operations Dashboard install to complete (Attempt $i of 400). Status: $STATUS"

    echo "Checking again in 15 seconds..."
    sleep 15
  fi
done

cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta2
kind: OperationsDashboardServiceBinding
metadata:
  name: ${release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
fi)
spec:
  odNamespace: "${namespace}"
  odInstanceName: "${release_name}"
  sourceInstanceName: "demo-tracing"
  sourcePodName: "demo-tracing"
  sourceSecretName: "icp4i-od-store-cred"
EOF
