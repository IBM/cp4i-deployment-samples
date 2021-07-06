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
  echo -e "$INFO [INFO] Using the pre-release catalog sources as specified at https://ibm.ent.box.com/notes/765437595126"
  cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  image: quay.io/opencloudio/ibm-common-service-catalog:3.7.4
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
  image: docker.io/ibmcom/ibm-automation-foundation-core-catalog:1.0.2
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
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog@sha256:83afb3c22f2a8d03b67eb43ffe40c5fd0b1c814494d66ffc5b903cdbcdb1d71d
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
  image: cp.stg.icr.io/cp/appconnect-operator-catalog@sha256:733a509b21f16f4cf2da325f9c2dd3ca02e20cb4ba8618244311353bb53e91e8
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
 image: cp.stg.icr.io/cp/ibm-mq-operator-catalog@sha256:f0404c2a1c543274c940c55a2f86f22c29ee6431a7e9a81a3cc00249d60ba005
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
  image: cp.stg.icr.io/cp/ibm-eventstreams-catalog@sha256:9eb1bf45628b58e8a68c6cb04e63a4381e136b6aae755cbf06a4ef4edddb1f60
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
  image: ibmcom/ibm-apiconnect-catalog@sha256:fbf789f0fb4882a95544979dad9c55752892dc42ae084af0548f6f7a52d03cf3
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
  image: icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:8461ee40e9188d12264d8fc108591122ae5546c73469f16dfc7a3bf07c52e322
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
  image: cp.stg.icr.io/cp/datapower-operator-catalog@sha256:a4ef16148b1500c97e058e3ae0f16d6729a3118b264dc3e0d2812f3603028cba
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
  image: cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog@sha256:1462cee2d79729c72b4d9b39399ddfd13c48c7f923a1e55ccdbb5df2091ada18
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
  image: cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog@sha256:bd532c3a076412af26a1c050bd1403ee9d6fe55c81a4561c96f7d2e51e2e08c5
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
  image: cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog@sha256:5048ac2bb95913bb47dc71b50beb619509447501ac5a92a6131a30d3c9b2e46a
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
  image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog@sha256:2df3723d4ad18f32853f7212e36274e2938a46347917fd3d4e759158f010a4d3
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
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
fi
