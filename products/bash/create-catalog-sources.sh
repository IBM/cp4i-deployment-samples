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
  displayName: "APIC Operators 4.10"
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:6f662e6bd23ca10653fbecee8c0460fab2beae0dd853e7bb0b7a8ea0181ebfa8
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: appconnect-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "ACE Operators 5.2.0"
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:32047af1807c0f0ad71aec649526e852627781f3f53287320f8d0808ec00d0d6
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-hsts-catalog
  namespace: openshift-marketplace
spec:
  displayName: "Aspera Operators latest"
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:2e292500ff510c3cf31ef1293ffaf9b56982da183f8d048aba392865cc27c3fc
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
  displayName: "Redis for Aspera Operators 1.5.3"
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:017f14861afa2d74c3fb0f51e44ca3eb130ff4a07b14338ee23f9bf2a8c2a129
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
  displayName: "IBMCS Operators v3.19.4"
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:50739c8fb13918f50c50363988aa4d9fba4974388a3a3b1199a48cfd5687ca9a
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "DP Operators 1.6.3"
  image: icr.io/cpopen/datapower-operator-catalog@sha256:36280a7a03bdeb4dcb562b5a90f2e2fd3d4cdd05a5b816e521c3f4ba3db6620c
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
  displayName: "ES Operators latest cd"
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
  displayName: "AR Operators 1.5.2"
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:c601c39808f4135abacf92adf9f2cf518ea7976fda95ef77b38d2ad7bb5a62f1
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-operations-dashboard-catalog
  namespace: openshift-marketplace
spec:
  displayName: "OD Operators 2.6.2"
  image: icr.io/cpopen/ibm-integration-operations-dashboard-catalog@sha256:a7a16646136622d5c921202403c55f42bf624dfa73ffe446ad80bbeae470c502
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
  displayName: "PN Operators PR 2930 build 11"
  # image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:latest-cd
  # From https://hyc-cip-jenkins.swg-devops.com/job/cp4i/job/cp4i-navigator-operator/view/change-requests/job/PR-2930/11/
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:7.0.0-2022-10-24-1734-dbdb47f3-predictable-im-child-crs@sha256:fb646136ab73c4f290067b030644c65bddfba3b304327fbe790bb3a8a9684c71
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
  displayName: "MQ Operators v2.0.3"
  image: cp.stg.icr.io/cp/ibm-mq-operator-catalog:latest-cd
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
