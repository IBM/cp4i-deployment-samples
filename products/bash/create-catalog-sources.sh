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
# ibm-integration-platform-navigator 7.3.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-platform-navigator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-platform-navigator-7.3.0
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:80ce1e6752d359870237ed30ba24f6271241e499e546214f30f4eb0962ec5029
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Automation foundation assets
# ibm-integration-asset-repository 1.7.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-asset-repository-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-asset-repository-1.7.0-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:cdfee2604f4c20f79668e6f7cadeec88d98ea45e8a1624cd520d48794e4c391a
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM API Connect
# ibm-apiconnect 5.2.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-apiconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-apiconnect-5.2.0
  publisher: IBM
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:61f52267bff3beb4455636763af4c95c6a5b7bc57b159ce0846d53364f2d4134
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-datapower-operator-1.11.0
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:3de18318c9e65e9ceaaedba95bc69a84393e88f1b57cc533ebbeba213dc5a1fd
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM App Connect
# ibm-appconnect 12.0.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: appconnect-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-appconnect-12.0.0
  publisher: IBM
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:c169dc7f7cdf9dda3c6ae20a999784d6a38ee5934aa7f2b30a6bb19bbf88829a
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM MQ
# ibm-mq 3.2.1
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibmmq-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-mq-3.2.1
  publisher: IBM
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:1259e16cd953d39bb0e722b45f17c3e26c7db44ee9ed55c1ece9556434672295
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Streams
# ibm-eventstreams 3.4.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventstreams
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventstreams-3.4.0
  publisher: IBM
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:786c707f975b9b0626f3626565ce6800acdbdda31b3170cce580ae4e4857df1d
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM DataPower Gateway
# ibm-datapower-operator 1.11.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-datapower-operator-1.11.0
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:3de18318c9e65e9ceaaedba95bc69a84393e88f1b57cc533ebbeba213dc5a1fd
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Aspera HSTS
# ibm-aspera-hsts-operator 1.5.13
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-aspera-hsts-operator-1.5.13
  publisher: IBM
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:8f75ef2c31ee0d7cb39ae0e5efacbc315483e659bdc024957490a7974de49427
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
  displayName: ibm-cloud-databases-redis-1.6.11
  publisher: IBM
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:dbdafdc70600a84099bd11df76b7a6728cbada513a1e06fefbc08f38406e3636
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Cloud Pak foundational services
# ibm-cp-common-services 4.6.3
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-cp-common-services-4.6.3
  publisher: IBM
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:93684df9c216eee6f26cab3f9dab69e1844a9e2b2bcea1261d578b1670346e02
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Endpoint Management
# ibm-eventendpointmanagement 11.2.0+20240603.010000
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventendpointmanagement-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventendpointmanagement-11.2.0+20240603.010000
  publisher: IBM
  image: icr.io/cpopen/ibm-eventendpointmanagement-operator-catalog@sha256:362b58b3d7d462e22af2a8210133382590cf5e5725b070940624647feefe5fea
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
