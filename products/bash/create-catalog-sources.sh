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


CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
YAML=$(cat <<EOF
#
# IBM Cloud Pak for Integration
# ibm-integration-platform-navigator 7.1.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-platform-navigator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-platform-navigator-7.1.0
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:4d23293d3786fbde27fe064148455ececd456261a2f0c51bb8f6426f8c8c1f25
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Automation foundation assets
# ibm-integration-asset-repository 1.5.9
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-asset-repository-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-asset-repository-1.5.9-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:1af42da7f7c8b12818d242108b4db6f87862504f1c57789213539a98720b0fed
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
  grpcPodConfig:
    nodeSelector:
      kubernetes.io/arch: amd64
---
#
# IBM API Connect
# ibm-apiconnect 5.0.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cloud-native-postgresql-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-cloud-native-postgresql-4.8.0+20221102.113620
  publisher: IBM
  image: icr.io/cpopen/ibm-cpd-cloud-native-postgresql-operator-catalog@sha256:3da7f227fee1034d585c2c76a643a6d749784ca005565de83b0016079c5151ac
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-apiconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-apiconnect-5.0.0
  publisher: IBM
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:9e1242d2e3de4cb0a0971e5bc8e2c71db6e86cfc8938b982614c03151b90fa1c
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM App Connect
# ibm-appconnect 8.2.1
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: appconnect-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-appconnect-8.2.1
  publisher: IBM
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:85e5679e67d9966708ac589c0e6266c11c6f45e282a28f37a4c8992dfb7d0bed
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM MQ
# ibm-mq 2.4.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibmmq-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-mq-2.4.0
  publisher: IBM
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:710220d34b45aeaff4d1a5fb2a76beb20b1de89eadf18f0d83a4bfd6ebe66646
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Streams
# ibm-eventstreams 3.2.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventstreams
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventstreams-3.2.0
  publisher: IBM
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:ac87cfecba0635a67c7d9b6c453c752cba9b631ffdd340223e547809491eb708
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM DataPower Gateway
# ibm-datapower-operator 1.7.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-datapower-operator-1.7.0-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:e82be67d0ffba2127a22b64d61a99ea4d23ede0a2fdf558d3c120fbfd39cf839
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
  grpcPodConfig:
    nodeSelector:
      kubernetes.io/arch: amd64
---
#
# IBM Aspera HSTS
# ibm-aspera-hsts-operator 1.5.8
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-aspera-hsts-operator-1.5.8
  publisher: IBM
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:ba2b97642692c627382e738328ec5e4b566555dcace34d68d0471439c1efc548
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cloud-databases-redis-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-cloud-databases-redis-1.6.6
  publisher: IBM
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:fddf96636005a9c276aec061a3b514036ce6d79bd91fd7e242126b2f52394a78
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Cloud Pak foundational services
# ibm-cp-common-services 1.19.4
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-cp-common-services-1.19.4
  publisher: IBM
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:cc3491ee7b448c3c8db43242d13e9d5d13a37ad9e67d166744d9b162887ed7e7
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Endpoint Management
# ibm-eventendpointmanagement 11.0.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventendpointmanagement-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventendpointmanagement-11.0.0-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-eventendpointmanagement-operator-catalog@sha256:d3e4503869e56f5656f1789ea3914be191c6f55486921b552f23b59540189551
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
  grpcPodConfig:
    nodeSelector:
      kubernetes.io/arch: amd64
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
