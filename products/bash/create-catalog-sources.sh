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
# ibm-integration-platform-navigator 7.3.8
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-platform-navigator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-platform-navigator-7.3.8
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:7f70c45873b1099ae2f874999e33c50004a10b785d6e86c2ba465dd08b44b1a8
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Automation foundation assets
# ibm-integration-asset-repository 1.7.7
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-integration-asset-repository-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-integration-asset-repository-1.7.7-linux-amd64
  publisher: IBM
  image: icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:855bfe87b33bbc650740dd54fdadbca5ef2856d4833c2ff7cb207001ecbeb9a2
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
  displayName: ibm-apiconnect-5.3.0
  publisher: IBM
  image: icr.io/cpopen/ibm-apiconnect-catalog@sha256:0561d5722a2173f1fba662a11b34707fe217b2fe105f56f370e6f2b7a5f43c14
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
  displayName: ibm-datapower-operator-1.11.3
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:69bc15ab3297d9f59811a6881baf2068dbbd96449d251f80ae98ff9d86879169
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM App Connect
# ibm-appconnect 12.0.7
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: appconnect-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-appconnect-12.0.7
  publisher: IBM
  image: icr.io/cpopen/appconnect-operator-catalog@sha256:786c6b2ad68f817587eaa186eed03b29ebf7cc1716d4614e6fd0047a1804daf4
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM MQ
# ibm-mq 3.2.7
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibmmq-operator-catalogsource
  namespace: openshift-marketplace
spec:
  displayName: ibm-mq-3.2.7
  publisher: IBM
  image: icr.io/cpopen/ibm-mq-operator-catalog@sha256:b315c23fae57b182502ae5ede5bf4bd12c76553df486e1129f1d0368636da516
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Streams
# ibm-eventstreams 3.5.2
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventstreams
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventstreams-3.5.2
  publisher: IBM
  image: icr.io/cpopen/ibm-eventstreams-catalog@sha256:c562ed95fcbb796b97793ede862f531ceb8e1a1ab6387601f25d27fc1dc3ad7f
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM DataPower Gateway
# ibm-datapower-operator 1.11.3
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-datapower-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-datapower-operator-1.11.3
  publisher: IBM
  image: icr.io/cpopen/datapower-operator-catalog@sha256:69bc15ab3297d9f59811a6881baf2068dbbd96449d251f80ae98ff9d86879169
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
# ibm-cp-common-services 4.6.8
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: ibm-cp-common-services-4.6.8
  publisher: IBM
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:4718a3491707165d2627d57a9ca7355939bc8671c045bc780dae5372c48e1ea5
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
---
#
# IBM Event Endpoint Management
# ibm-eventendpointmanagement 11.4.0
#
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-eventendpointmanagement-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-eventendpointmanagement-11.4.0
  publisher: IBM
  image: icr.io/cpopen/ibm-eventendpointmanagement-operator-catalog@sha256:f33af6b5610d835dfe48fe814c724ad4040e45e439b47053442322403c40d973
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
EOF
)
OCApplyYAML "openshift-marketplace" "$YAML"
