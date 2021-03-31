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
#   -r : <release-name> (string), Defaults to "ademo"
#   -t : optional flag to enable tracing
#
# USAGE:
#   With defaults values
#     ./release-apic.sh
#
#   Overriding the namespace and release-name
#     ./release-apic.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name> [-t]"
}

namespace="cp4i"
release_name="ademo"
tracing="false"
production="false"
CURRENT_DIR=$(dirname $0)

while getopts "n:r:tp" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  t)
    tracing=true
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

profile="n1xc10.m48"
license_use="nonproduction"
source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] APIC license: $(getAPICLicense $namespace)"

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  profile="n12xc4.m12"
  license_use="production"
fi

json=$(oc get configmap -n $namespace operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

cat <<EOF | oc apply -f -
apiVersion: apiconnect.ibm.com/v1beta1
kind: APIConnectCluster
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
  labels:
    app.kubernetes.io/instance: apiconnect
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: apiconnect-production
spec:
  version: 10.0.2.0
  license:
    accept: true
    use: ${license_use}
    license: $(getAPICLicense $namespace)
  profile: ${profile}
  gateway:
    openTracing:
      enabled: ${tracing}
      odTracingNamespace: ${namespace}
      imageAgent: 'cp.icr.io/cp/icp4i/od/icp4i-od-agent:1.1.0-rc6-amd64@sha256:9143f522727dcfa7e3a45dee17aff324df52fe05f4d6a40466859a084db59e4f'
      imageCollector: 'cp.icr.io/cp/icp4i/od/icp4i-od-collector:1.1.0-rc6-amd64@sha256:2c17a1bb5d45fa0b8bae6f2581ec6f5308a605b6a8934b78188eda3c6a0ef21f'
    replicaCount: 1
  management:
    testAndMonitor:
      enabled: true
EOF
