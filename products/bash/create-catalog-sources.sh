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
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:e3950b6d9c2f86ec1be3deb6db1cb2e479592c3d288de94fe239fa9d01e6d445
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
  displayName: "ACE Operators 6.2.0"
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:932919a5aeb07d00035f4b30e31df4825fba202e061df58f0c5a9af4b084b841
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
  image: icr.io/cpopen/aspera-hsts-catalog@sha256:56f539747689c755edb01ffd3266e3f438bfa978ee36fb2a872b41951d3301aa
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
  name: datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "DP Operators 1.6.4"
  image: icr.io/cpopen/datapower-operator-catalog@sha256:aa1872bcebcc9912823821ff34376fddd016e2bcdd76e0298b51c3187669169f
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
  displayName: "ES Operators v3.1.1"
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:fb4a1b232ab796b2ae75616e071415ad17582d0539727f532abf6416f07403f5
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
  displayName: "AR Operators 1.5.4"
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:89cd0b2bfc66241cfaf542de906982434c23d1c6391db72fc6ef99d851568abe
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
  displayName: "OD Operators 2.6.5"
  image: icr.io/cpopen/ibm-integration-operations-dashboard-catalog@sha256:12e7be1060f015286a5b3e16054d08e09068d02fb16a95f03f581a9ce82b3ebe
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
  displayName: "PN Operators 7.0.0"
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:d98a7858cef16b558969d8cb5490f0916e89ad8fd4ca5baa0ce20580ccf9bef6
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
  displayName: "MQ Operators v2.2.0"
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:b1d90cc6a3bf02b70668d0c07402a47258f85792ffca67d5ce73e5e34fde297d
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
