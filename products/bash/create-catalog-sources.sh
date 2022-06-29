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

INFO="\xE2\x84\xB9"

# TODO Below pre-release versions taken from https://hyc-cip-jenkins.swg-devops.com/job/Automation/job/test/job/e2e-test/job/main/1545/

# See the find-catalog-sources/README.md for how to create/update the following list of env vars:
WML_TRAINING_CATALOG_NAME=ibm-ai-wmltraining-operator-catalog
WML_TRAINING_CATALOG_IMAGE=icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
WML_TRAINING_CATALOG_DISPLAY_NAME="WML Training Operators 1.1.0"
APIC_CATALOG_NAME=ibm-apiconnect-catalog
# APIC_CATALOG_IMAGE=icr.io/cpopen/ibm-apiconnect-catalog@sha256:214c287742fb86a943f593179616a7f1d265ee948e36da4e11d7504368917ff9
# APIC_CATALOG_DISPLAY_NAME="APIC Operators 4.9"
APIC_CATALOG_IMAGE=icr.io/cpopen/ibm-apiconnect-catalog@sha256:5514de8857f1f971448eccc043cec046afccf7c887097477a2f57d4f864b0476
APIC_CATALOG_DISPLAY_NAME="APIC Operators 2022.2.1 Pre-release"
ACE_CATALOG_NAME=appconnect-operator-catalog
ACE_CATALOG_IMAGE=icr.io/cpopen/appconnect-operator-catalog@sha256:da0023a6f68f813a872e4ceae2f81ce38041ecda198713cef19dda43820ad640
ACE_CATALOG_DISPLAY_NAME="ACE Operators 5.0.0"
ASPERA_CATALOG_NAME=aspera-hsts-catalog
# ASPERA_CATALOG_IMAGE=icr.io/cpopen/aspera-hsts-catalog@sha256:69bcdd83f138306b1510d5835e44245808d2a435f3c7705b75ac7309c0eb207c
# ASPERA_CATALOG_DISPLAY_NAME="Aspera Operators latest"
ASPERA_CATALOG_IMAGE=cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog@sha256:4d793923a1a2eb73e5db3d3da160316afd6510b2070a66702adc47ccf3d50ced
ASPERA_CATALOG_DISPLAY_NAME="Aspera Operators 2022.2.1 Pre-release"
REDIS_CATALOG_NAME=ibm-cloud-databases-redis-catalog
REDIS_CATALOG_IMAGE=icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:7ed8781a8ca2afa08960a4eb7dccb467e821f875bdfbd8f3cdabd746800ee846
REDIS_CATALOG_DISPLAY_NAME="Redis for Aspera Operators 1.5.2"
COMMON_SERVICES_CATALOG_NAME=ibm-common-service-catalog
COMMON_SERVICES_CATALOG_IMAGE=icr.io/cpopen/ibm-common-service-catalog@sha256:8fb50af805915ba40e69aaa123dcb0cb859921e476d02adf109e62130b6d1008
COMMON_SERVICES_CATALOG_DISPLAY_NAME="IBMCS Operators v3.19.0"
DATAPOWER_CATALOG_NAME=datapower-operator-catalog
# DATAPOWER_CATALOG_IMAGE=icr.io/cpopen/datapower-operator-catalog@sha256:3995b3114b3ef872cccf76f8c3bdc15df0a01d039b9957a280b9571ffbb1fa50
# DATAPOWER_CATALOG_DISPLAY_NAME="DP Operators 1.5.3"
DATAPOWER_CATALOG_IMAGE=cp.stg.icr.io/cp/datapower-operator-catalog@sha256:dd3c631a1f51ce4933b8bb450160ced0667cdc5c5c9314e4033a55222faa92d5
DATAPOWER_CATALOG_DISPLAY_NAME="DP Operators 2022.2.1 Pre-release"
EVENT_STREAMS_CATALOG_NAME=ibm-eventstreams-catalog
EVENT_STREAMS_CATALOG_IMAGE=icr.io/cpopen/ibm-eventstreams-catalog@sha256:c2114a611291377b04760066d89b650f1f19cda5ff33b4f0517f728ad2106456
EVENT_STREAMS_CATALOG_DISPLAY_NAME="ES Operators v3.0.2"
ASSET_REPO_CATALOG_NAME=ibm-integration-asset-repository-catalog
ASSET_REPO_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:a68d1e925263090eb30061b38944a030e13cf5a8910a6f0e5aa047dc9a6b9614
ASSET_REPO_CATALOG_DISPLAY_NAME="AR Operators 1.5.0"
OPERATIONS_DASHBOARD_CATALOG_NAME=ibm-integration-operations-dashboard-catalog
OPERATIONS_DASHBOARD_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-operations-dashboard-catalog@sha256:e9c2b98879ac9f6ba08992c04a5efcec8df74fef04711438383a5577f48034c1
OPERATIONS_DASHBOARD_CATALOG_DISPLAY_NAME="OD Operators 2.6.0"
NAVIGATOR_CATALOG_NAME=ibm-integration-platform-navigator-catalog
NAVIGATOR_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:e67b85bc65246d0d023ca9ca79a6a7b510431aa831668a5074bc555075aec58d
NAVIGATOR_CATALOG_DISPLAY_NAME="PN Operators 6.0.0"
MQ_CATALOG_NAME=ibm-mq-operator-catalog
MQ_CATALOG_IMAGE=icr.io/cpopen/ibm-mq-operator-catalog@sha256:ce5cbb440329131346ab1b5b63751042de8c5285acc480231d51961305872618
MQ_CATALOG_DISPLAY_NAME="MQ Operators v2.0.0"

function create_catalog_source() {
  CATALOG_NAME=${1}
  CATALOG_IMAGE=${2}
  CATALOG_DISPLAY_NAME=${3}
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOG_NAME}
  namespace: openshift-marketplace
spec:
  displayName: ${CATALOG_DISPLAY_NAME}
  image: ${CATALOG_IMAGE}
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

echo -e "$INFO [INFO] Applying catalogsources\n"
create_catalog_source ${WML_TRAINING_CATALOG_NAME} ${WML_TRAINING_CATALOG_IMAGE} ${WML_TRAINING_CATALOG_DISPLAY_NAME}
create_catalog_source ${APIC_CATALOG_NAME} ${APIC_CATALOG_IMAGE} ${APIC_CATALOG_DISPLAY_NAME}
create_catalog_source ${ACE_CATALOG_NAME} ${ACE_CATALOG_IMAGE} ${ACE_CATALOG_DISPLAY_NAME}
create_catalog_source ${ASPERA_CATALOG_NAME} ${ASPERA_CATALOG_IMAGE} ${ASPERA_CATALOG_DISPLAY_NAME}
create_catalog_source ${REDIS_CATALOG_NAME} ${REDIS_CATALOG_IMAGE} ${REDIS_CATALOG_DISPLAY_NAME}
create_catalog_source ${COMMON_SERVICES_CATALOG_NAME} ${COMMON_SERVICES_CATALOG_IMAGE} ${COMMON_SERVICES_CATALOG_DISPLAY_NAME}

create_catalog_source ${DATAPOWER_CATALOG_NAME} ${DATAPOWER_CATALOG_IMAGE} ${DATAPOWER_CATALOG_DISPLAY_NAME}
create_catalog_source ${EVENT_STREAMS_CATALOG_NAME} ${EVENT_STREAMS_CATALOG_IMAGE} ${EVENT_STREAMS_CATALOG_DISPLAY_NAME}
create_catalog_source ${ASSET_REPO_CATALOG_NAME} ${ASSET_REPO_CATALOG_IMAGE} ${ASSET_REPO_CATALOG_DISPLAY_NAME}
create_catalog_source ${OPERATIONS_DASHBOARD_CATALOG_NAME} ${OPERATIONS_DASHBOARD_CATALOG_IMAGE} ${OPERATIONS_DASHBOARD_CATALOG_DISPLAY_NAME}
create_catalog_source ${NAVIGATOR_CATALOG_NAME} ${NAVIGATOR_CATALOG_IMAGE} ${NAVIGATOR_CATALOG_DISPLAY_NAME}
create_catalog_source ${MQ_CATALOG_NAME} ${MQ_CATALOG_IMAGE} ${MQ_CATALOG_DISPLAY_NAME}
