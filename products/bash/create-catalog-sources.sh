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
  name: ibm-ai-wmltraining-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "WML Training Operators 1.1.1"
  image: icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:6bc72737c10c985de0f1325c50382fc2dd1ceb811fd0948bd1eef58f544d9188
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-apiconnect-catalog
  namespace: openshift-marketplace
spec:
  displayName: "APIC Operators 4.10"
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:5d54fe6f7bb4db9e3255f1e24d194cc06b7917181368883fba1e6aa0e9e83eaa
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
  displayName: "ACE Operators 5.0.0"
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:da0023a6f68f813a872e4ceae2f81ce38041ecda198713cef19dda43820ad640
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
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:9b961dd0be0f6849dfae56f2acbdf66184f88308b01e276a85e0b96d51e13c51
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
  displayName: "Redis for Aspera Operators 1.5.2"
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:7ed8781a8ca2afa08960a4eb7dccb467e821f875bdfbd8f3cdabd746800ee846
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
  displayName: "IBMCS Operators v3.19.0"
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:8fb50af805915ba40e69aaa123dcb0cb859921e476d02adf109e62130b6d1008
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
  displayName: "DP Operators 1.6.0"
  image: icr.io/cpopen/datapower-operator-catalog@sha256:dd3c631a1f51ce4933b8bb450160ced0667cdc5c5c9314e4033a55222faa92d5
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
  displayName: "ES Operators v3.0.3"
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:1d3217f4d789d9b3ddca229e9d39ce4d80da9b4fb3470b73377e161c065a6fb2
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
  displayName: "AR Operators 1.5.0"
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:a68d1e925263090eb30061b38944a030e13cf5a8910a6f0e5aa047dc9a6b9614
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
  displayName: "PN Operators 6.0.0"
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:e67b85bc65246d0d023ca9ca79a6a7b510431aa831668a5074bc555075aec58d
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
  displayName: "MQ Operators v2.0.0"
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:ce5cbb440329131346ab1b5b63751042de8c5285acc480231d51961305872618
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
