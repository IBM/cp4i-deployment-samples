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
#   -p : Use pre-release catalog sources
#
# USAGE:
#   With defaults values
#     ./create-catalog-sources.sh
#
#   Using pre-release catalog sources
#     ./create-catalog-sources.sh -p
#

function usage() {
  echo "Usage: $0 -p"
  exit 1
}

USE_PRERELEASE_CATALOGS=false
INFO="\xE2\x84\xB9"

while getopts "p" opt; do
  case ${opt} in
  p)
    USE_PRERELEASE_CATALOGS=true
    ;;
  \?)
    usage
    ;;
  esac
done

echo -e "$INFO [INFO] Applying catalogsources\n"
if [[ "${USE_PRERELEASE_CATALOGS}" == "true" ]]; then
  echo -e "$INFO [INFO] Using the Q4 pre-release catalog sources as specified at https://ibm.ent.box.com/notes/881484983929"
  cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:latest-validated
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: automation-base-pak-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMABP Operators
  image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:latest-validated
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: pn-operators
  namespace: openshift-marketplace
spec:
  displayName: PN Operators
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ace-operators
  namespace: openshift-marketplace
spec:
  displayName: ACE Operators
  image: cp.stg.icr.io/cp/appconnect-operator-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
 name: mq-operators
 namespace: openshift-marketplace
spec:
 displayName: MQ Operators
 image: cp.stg.icr.io/cp/ibm-mq-operator-catalog@sha256:bd686e3aee196ce92ba34356afcc95e95c0121679784ae91e8ed342df437eed0
 publisher: IBM
 sourceType: grpc
 updateStrategy:
   registryPoll:
     interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: es-operators
  namespace: openshift-marketplace
spec:
  displayName: ES Operators
  image: cp.stg.icr.io/cp/ibm-eventstreams-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: apic-operators
  namespace: openshift-marketplace
spec:
  displayName: APIC Operators
  image: cp.stg.icr.io/cp/ibm-apiconnect-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-ai-wmltraining-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: dp-operators
  namespace: openshift-marketplace
spec:
  displayName: DP Operators
  image: cp.stg.icr.io/cp/datapower-operator-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-redis-operators
  namespace: openshift-marketplace
spec:
  displayName: Redis for Aspera Operators
  image: cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog@sha256:bb65ca87c987b040b0a8cea4cf44af9bf1a0110442f249529032dd580cc29b36
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-operators
  namespace: openshift-marketplace
spec:
  displayName: Aspera Operators
  image: cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog@sha256:1b6e1e5437c427815eeb483f0db010aff7e27983cbe4a35a368919e3d339a925
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ar-operators
  namespace: openshift-marketplace
spec:
  displayName: AR Operators
  image: cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog:1.3.2-2021-09-06-1534-815bfd8b-service-v2021.2.1-1-amd64@sha256:9c065c84879686e4a45b9f23a121958f59d9372c1378e8b75536405da1d10693
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: od-operators
  namespace: openshift-marketplace
spec:
  displayName: OD Operators
  image: icr.io/cpopen/ibm-integration-operations-dashboard-catalog:2.5.0-2021-11-12-0957-0c2dac20@sha256:4b01abb219dddc2808895d4e15f0de9b33f546cce5cfb6281e6dda0f5c34bb41
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cp4i-demo-operator-catalog-source
  namespace: openshift-marketplace
spec:
  displayName: Demo Operators
  sourceType: grpc
  image: cp.stg.icr.io/cp/ibm-integration-demos-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
EOF
else
  echo -e "$INFO [INFO] Using the release catalog sources"
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Operator Catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
fi
