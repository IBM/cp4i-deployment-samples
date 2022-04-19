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
#     ./release-apic.sh -n cp4i-prod -r prod -a false

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name> [-t]"
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
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

license_use="nonproduction"
source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] APIC license: $(getAPICLicense $namespace)"

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  profile="n12xc4.m12"
  license_use="production"
else
  profile="n1xc10.m48"
fi

json=$(oc get configmap -n $namespace operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

time=0
until cat <<EOF | oc apply -f -; do
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
  gateway:
    openTracing:
      enabled: ${tracing}
      odTracingNamespace: ${namespace}
    replicaCount: 1
  license:
    accept: true
    use: ${license_use}
    license: $(getAPICLicense $namespace)
  profile: ${profile}
  version: 10.0.4.0
EOF
  if [ $time -gt 10 ]; then
    echo "ERROR: Exiting installation as timeout waiting for APIConnectCluster to be created"
    exit 1
  fi
  echo "INFO: Waiting up to 10 minutes for APIConnectCluster to be created. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
done
