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
#   -r : <release-name> (string), Defaults to "demo"
#
# USAGE:
#   With defaults values
#     ./release-ar.sh
#
#   Overriding the namespace and release-name
#     ./release-ar.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name> -a <assets storage class (file)> -c <couch storage class (block)>"
}

namespace="cp4i"
release_name="demo"
assetDataVolume="ibmc-file-gold-gid"
couchVolume="ibmc-block-gold"
CURRENT_DIR=$(dirname $0)

while getopts "n:r:a:c:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  a)
    assetDataVolume="$OPTARG"
    ;;
  c)
    couchVolume="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] AR license: $(getARLicense $namespace)"

json=$(oc get configmap -n $namespace operator-info -o json 2> /dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: AssetRepository
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
  designerAIFeatures:
    enabled: true
  license:
    accept: true
    license: $(getARLicense $namespace)
  replicas: 1
  storage:
    assetDataVolume:
      class: ${assetDataVolume}
    couchVolume:
      class: ${couchVolume}
  version: 2021.2.1-0
EOF

echo "patching service account"

oc patch serviceaccount default -n $namespace -p '{"imagePullSecrets": [{"name": "ibm-entitlement-key"}]}'

time=0
while ! oc get pod -n $namespace -l inter-pod-anti-affinity=$release_name-ibm-integration-asset-repository-nlp -o jsonpath='{.items[].metadata.name}' 2> /dev/null; do
  if [ $time -gt 10 ]; then
    echo -e "\n$CROSS [ERROR] Timed-out trying to wait for $release_name-ibm-integration-asset-repository-nlp pod to appear in the '$namespace' namespace"
    divider
    exit 1
  fi
  echo -e "$INFO [INFO] Waiting for upto 10 minutes for $release_name-ibm-integration-asset-repository-nlp pod in '$namespace' namespace to appear. Waited $time minute(s)"
  time=$((time + 1))
  sleep 60
done

AR_NLP_POD=$(oc get pod -n $namespace -l inter-pod-anti-affinity=$release_name-ibm-integration-asset-repository-nlp -o jsonpath='{.items[].metadata.name}')

oc delete pod $AR_NLP_POD