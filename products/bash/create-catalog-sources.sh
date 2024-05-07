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
# ibm-integration-platform-navigator 7.2.4
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-platform-navigator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-platform-navigator-7.2.4
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:71d5b07bb009e9b111a5755c191a6dd3d5a80c24f371f93d25d30a22d6339a35
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Automation foundation assets
# ibm-integration-asset-repository 1.6.4
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-asset-repository-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-asset-repository-1.6.4-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:7f63fb899609f79ef57eadb8ba1788d9d1ca09197ca56dc32e8916a68bd511c0
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM API Connect
# ibm-apiconnect 5.1.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-apiconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-apiconnect-5.1.0
  publisher: IBM
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:2058d863696e3adccd620ab3210a84f792c2953e42a9b61f350b4ad897723f1e
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
  displayName: ibm-datapower-operator-1.9.0-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:709199367366fe22ffd9791a975e268f736903b55605eff99f031982bf9b4c68
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
  grpcPodConfig:
    nodeSelector:
      kubernetes.io/arch: amd64
---
#
# IBM App Connect
# ibm-appconnect 11.1.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: appconnect-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-appconnect-11.1.0
  publisher: IBM
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:05c9cdc95390e2a17776fd276966db73adb67e4a687f129620aeb3f796f71ba7
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM MQ
# ibm-mq 3.0.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibmmq-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-mq-3.0.0
  publisher: IBM
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:99b43b78e103fa18ea91827286c865219493a056e6f002096558a2dd1655c9b7
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Streams
# ibm-eventstreams 3.3.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventstreams
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventstreams-3.3.0
  publisher: IBM
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:b0c0035a38dc6cb990ea4d452f1f083c74e3b0aedf6154d709f6f2a41ffb12af
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM DataPower Gateway
# ibm-datapower-operator 1.9.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-datapower-operator-1.9.0-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:709199367366fe22ffd9791a975e268f736903b55605eff99f031982bf9b4c68
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
# ibm-aspera-hsts-operator 1.5.12
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-aspera-hsts-operator-1.5.12
  publisher: IBM
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:536446293eea0a8804abaec6ec290a7f448bbdf95de44f38d8c36aacf7c0b143
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
# ibm-cp-common-services 4.6.1
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-cp-common-services-4.6.1
  publisher: IBM
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:3741dd89c58a5a87da26032d466e514e113d6727d0c77f8e483b1213df10dcf3
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Endpoint Management
# ibm-eventendpointmanagement 11.1.1
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventendpointmanagement-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventendpointmanagement-11.1.1-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-eventendpointmanagement-operator-catalog@sha256:ea0fccc22503422d8b07dc0baf991c98d83596b29027749b2e3ebabb723bd355
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
