#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -d <Update Default Storage Class (true/false, defaults to false)>"
  divider
  exit 1
}

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
updateDefaultSC="false"
DUMMY_NAMESPACE="default"

while getopts "d:" opt; do
  case ${opt} in
  d)
    updateDefaultSC="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

# This storage class improves the pvc performance for small PVCs
echo -e "$INFO [INFO] Creating new cp4i-block-performance storage class\n"
YAML=$(cat <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-block-performance
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-block
parameters:
  billingType: "hourly"
  classVersion: "2"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
)
OCApplyYAML "$DUMMY_NAMESPACE" "$YAML"

echo -e "$INFO [INFO] Creating new cp4i-file-performance-gid storage class\n"
YAML=$(cat <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-file-performance-gid
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-file
parameters:
  billingType: "hourly"
  classVersion: "2"
  gidAllocate: "true"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
)
OCApplyYAML "$DUMMY_NAMESPACE" "$YAML"

if [[ "$updateDefaultSC" == "true" ]]; then
    defaultStorageClass=$(oc get sc -o json | jq -r '.items[].metadata | select(.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .name')
    echo -e "\n$INFO [INFO] Current default storage class is: $defaultStorageClass"

    echo -e "\n$INFO [INFO] Making $defaultStorageClass non-default\n"
    oc patch storageclass $defaultStorageClass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

    echo -e "\n$INFO [INFO] Making cp4i-block-performance default\n"
    oc patch storageclass cp4i-block-performance -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi
