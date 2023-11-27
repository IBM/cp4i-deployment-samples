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

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
namespace="cp4i"
release_name="ademo"
production="false"

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
  profile="n1xc7.m48"
fi

json=$(oc get configmap -n $namespace operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

YAML=$(cat <<EOF
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
  annotations:
    apiconnect-operator/backups-not-configured: 'true'
  labels:
    app.kubernetes.io/instance: apiconnect
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: apiconnect-production
spec:
  gateway:
    replicaCount: 1
  license:
    accept: true
    use: ${license_use}
    license: "L-MMBZ-295QZQ"
  profile: ${profile}
  version: "10.0.7.0"
EOF
)
OCApplyYAML "$namespace" "$YAML"
