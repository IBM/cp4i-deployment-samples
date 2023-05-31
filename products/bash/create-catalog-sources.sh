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
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-apiconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: "APIC Operators latest-cd"
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
  name: ibm-appconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: "ACE Operators latest-cd"
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
  name: ibm-aspera-hsts-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "Aspera Operators latest"
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:a1c401135c5a4a9f3c88e2ac9b75299b9be376d6f97f34d7f68f2a31f0c726cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cloud-databases-redis-catalog
  namespace: openshift-marketplace
spec:
  displayName: "Redis for Aspera Operators 1.6.2"
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:68dfcc9bb5b39990171c30e20fee337117c7385a07c4868efd28751d15e08e9f
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-common-service-catalog
  namespace: openshift-marketplace
spec:
  displayName: "IBMCS Operators v3.22.0"
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:36c410c39a52c98919f22f748e67f7ac6d3036195789d9cfbcd8a362dedbb2bd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "DP Operators latest-cd"
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
  name: ibm-eventstreams-catalog
  namespace: openshift-marketplace
spec:
  displayName: "ES Operators latest-cd"
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
  name: ibm-integration-asset-repository-catalog
  namespace: openshift-marketplace
spec:
  displayName: "AR Operators latest-cd"
  image: cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-platform-navigator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "PN Operators staging image"
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:latest-cd
  # displayName: "PN Operators Dans"
  # image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:7.1.0-2023-05-25-1452-1848b312-mq-update-fix@sha256:ef27ccf7e67875ea10c2a68eac6104281089c3198c462fb8e54d820f7057551f
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-mq-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "MQ Operators latest-cd"
  image: cp.stg.icr.io/cp/ibm-mq-operator-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
