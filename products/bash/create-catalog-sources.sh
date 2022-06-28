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
WML_TRAINING_CATALOG_NAME=ibm-ai-wmltraining-catalog
WML_TRAINING_CATALOG_IMAGE=icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
WML_TRAINING_CATALOG_DISPLAY_NAME="WML Training Operators 1.1.1"
APIC_CATALOG_NAME=apic-operators
#APIC_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-apiconnect-catalog@sha256:c8ea09c92bcfbb18829eb5c08d4f099af4b800d8813a4dd22db25b99de6d7f37
APIC_CATALOG_IMAGE=icr.io/cpopen/ibm-apiconnect-catalog@sha256:5514de8857f1f971448eccc043cec046afccf7c887097477a2f57d4f864b0476
APIC_CATALOG_DISPLAY_NAME="APIC Operators 2022.2.1 Pre-release"
ACE_CATALOG_NAME=ace-operators
ACE_CATALOG_IMAGE=cp.stg.icr.io/cp/appconnect-operator-catalog@sha256:56df4ba338d533b8d0db555ff1803404a2bc5620d545a3ab08dbe8cf7ebbb12a
ACE_CATALOG_DISPLAY_NAME="ACE Operators 2022.2.1 Pre-release"
ASPERA_CATALOG_NAME=aspera-operators
ASPERA_CATALOG_IMAGE=cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog@sha256:4d793923a1a2eb73e5db3d3da160316afd6510b2070a66702adc47ccf3d50ced
ASPERA_CATALOG_DISPLAY_NAME="Aspera Operators 2022.2.1 Pre-release"
REDIS_CATALOG_NAME=aspera-redis-operators
REDIS_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog@sha256:4aa56dd1e90065668a280d6eb34f5793bf5f54b0479f46d635343400560b9dcd
REDIS_CATALOG_DISPLAY_NAME="Redis for Aspera Operators 2022.2.1 Pre-release"
COMMON_SERVICES_CATALOG_NAME=ibm-common-service-catalog
COMMON_SERVICES_CATALOG_IMAGE=icr.io/cpopen/ibm-common-service-catalog@sha256:8fb50af805915ba40e69aaa123dcb0cb859921e476d02adf109e62130b6d1008
COMMON_SERVICES_CATALOG_DISPLAY_NAME="IBMCS Operators v3.19.0"
DATAPOWER_CATALOG_NAME=dp-operators
DATAPOWER_CATALOG_IMAGE=cp.stg.icr.io/cp/datapower-operator-catalog@sha256:dd3c631a1f51ce4933b8bb450160ced0667cdc5c5c9314e4033a55222faa92d5
DATAPOWER_CATALOG_DISPLAY_NAME="DP Operators 2022.2.1 Pre-release"
EVENT_STREAMS_CATALOG_NAME=es-operators
EVENT_STREAMS_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-eventstreams-catalog@sha256:550d886742f90cea1cd42b80eafe7c9a21bafb9bf2ac5c1de7d183bf7802954a
EVENT_STREAMS_CATALOG_DISPLAY_NAME="ES Operators 2022.2.1 Pre-release"
ASSET_REPO_CATALOG_NAME=ar-operators
ASSET_REPO_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog@sha256:a68d1e925263090eb30061b38944a030e13cf5a8910a6f0e5aa047dc9a6b9614
ASSET_REPO_CATALOG_DISPLAY_NAME="AR Operators 2022.2.1 Pre-release"
OPERATIONS_DASHBOARD_CATALOG_NAME=od-operators
OPERATIONS_DASHBOARD_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog@sha256:e9c2b98879ac9f6ba08992c04a5efcec8df74fef04711438383a5577f48034c1
OPERATIONS_DASHBOARD_CATALOG_DISPLAY_NAME="OD Operators 2022.2.1 Pre-release"
NAVIGATOR_CATALOG_NAME=pn-operators
NAVIGATOR_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog@sha256:5be84a8103c894abebd4836cba7be54152788d373b82a7a2e83497a32c5d6574
NAVIGATOR_CATALOG_DISPLAY_NAME="PN Operators 2022.2.1 Pre-release"
MQ_CATALOG_NAME=mq-operators
MQ_CATALOG_IMAGE=cp.stg.icr.io/cp/ibm-mq-operator-catalog@sha256:9caf9697a9bb03853965cb8335323a0a20f1b4c74fea1bbb6cb2a34c4b74d953
MQ_CATALOG_DISPLAY_NAME="MQ Operators 2022.2.1 Pre-release"

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
