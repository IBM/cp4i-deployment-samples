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

WML_TRAINING_CATALOG_NAME=ibm-ai-wmltraining-catalog
WML_TRAINING_CATALOG_IMAGE=icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
WML_TRAINING_CATALOG_DISPLAY_NAME="WML Training Operators 1.1.1"
APIC_CATALOG_NAME=apic-operators
APIC_CATALOG_IMAGE=icr.io/cpopen/ibm-apiconnect-catalog@sha256:214c287742fb86a943f593179616a7f1d265ee948e36da4e11d7504368917ff9
APIC_CATALOG_DISPLAY_NAME="APIC Operators 3.0.7"
ACE_CATALOG_NAME=ace-operators
ACE_CATALOG_IMAGE=icr.io/cpopen/appconnect-operator-catalog@sha256:d70302c0d7ecd0a17a7256b3e62fb0d6039797021a42728cf681940d012372ae
ACE_CATALOG_DISPLAY_NAME="ACE Operators 4.1.0"
ASPERA_CATALOG_NAME=aspera-operators
ASPERA_CATALOG_IMAGE=icr.io/cpopen/aspera-hsts-catalog@sha256:69bcdd83f138306b1510d5835e44245808d2a435f3c7705b75ac7309c0eb207c
ASPERA_CATALOG_DISPLAY_NAME="Aspera Operators 1.4.1"
IAF_CATALOG_NAME=automation-base-pak-operators
IAF_CATALOG_IMAGE=icr.io/cpopen/ibm-automation-foundation-core-catalog@sha256:0bd8ed8ee6807f780471d05bca46dea5b1eb9edcbd76587d08fa94fe9fa27c25
IAF_CATALOG_DISPLAY_NAME="IBMABP Operators 1.3.6"
REDIS_CATALOG_NAME=aspera-redis-operators
REDIS_CATALOG_IMAGE=icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:0f288d16fa18af1af176398cd066a4fb549d811067a41668b05ef4b60ed6088a
REDIS_CATALOG_DISPLAY_NAME="Redis for Aspera Operators 1.4.5"
COUCHDB_CATALOG_NAME=couchdb-operators
COUCHDB_CATALOG_IMAGE=icr.io/cpopen/couchdb-operator-catalog@sha256:c35df32a8de999a4bb76229fbe302b1107d9c6bd17d159ee30167016c51bc215
COUCHDB_CATALOG_DISPLAY_NAME="IBM CouchDB Operators 1.0.13"
COMMON_SERVICES_CATALOG_NAME=opencloud-operators
COMMON_SERVICES_CATALOG_IMAGE=icr.io/cpopen/ibm-common-service-catalog@sha256:f637b2888f7be48760b3925e906216f8565ab6b036172b21c87506fbdd53020a
COMMON_SERVICES_CATALOG_DISPLAY_NAME="IBMCS Operators 1.13.0"

DATAPOWER_CATALOG_NAME=dp-operators
DATAPOWER_CATALOG_IMAGE=icr.io/cpopen/datapower-operator-catalog@sha256:3995b3114b3ef872cccf76f8c3bdc15df0a01d039b9957a280b9571ffbb1fa50
DATAPOWER_CATALOG_DISPLAY_NAME="DP Operators 1.5.3"
EVENT_STREAMS_CATALOG_NAME=es-operators
EVENT_STREAMS_CATALOG_IMAGE=icr.io/cpopen/ibm-eventstreams-catalog@sha256:76b1f2637c5ed871f66ee4e89b4b48fe91aef7613a894f9bdf6638a493ab0cdc
EVENT_STREAMS_CATALOG_DISPLAY_NAME="ES Operators 1.6.1"
ASSET_REPO_CATALOG_NAME=ar-operators
ASSET_REPO_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-asset-repository-catalog@sha256:ef993b1eca79044918d1757559598d167ed34321d55310aa8c9171c138ec085d
ASSET_REPO_CATALOG_DISPLAY_NAME="AR Operators 1.4.5"
OPERATIONS_DASHBOARD_CATALOG_NAME=od-operators
OPERATIONS_DASHBOARD_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-operations-dashboard-catalog@sha256:53b8d24b9650e5e82cac5d4c33000372439826bfe874a8565ed49f46a33e7f8c
OPERATIONS_DASHBOARD_CATALOG_DISPLAY_NAME="OD Operators 2.5.5"
NAVIGATOR_CATALOG_NAME=pn-operators
NAVIGATOR_CATALOG_IMAGE=icr.io/cpopen/ibm-integration-platform-navigator-catalog@sha256:b41fd254ab7f503f65409a4a417d65fb1f3d9950fc5ea9dac30ec2f29ec31e4d
NAVIGATOR_CATALOG_DISPLAY_NAME="PN Operators 1.6.1"
MQ_CATALOG_NAME=mq-operators
MQ_CATALOG_IMAGE=icr.io/cpopen/ibm-mq-operator-catalog@sha256:8ad0fe91b535b6169933b0270ea7266fcaf73173f26ea17bb50255c39d5b2aa6
MQ_CATALOG_DISPLAY_NAME="MQ Operators 1.8.1"

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
create_catalog_source ${IAF_CATALOG_NAME} ${IAF_CATALOG_IMAGE} ${IAF_CATALOG_DISPLAY_NAME}
create_catalog_source ${REDIS_CATALOG_NAME} ${REDIS_CATALOG_IMAGE} ${REDIS_CATALOG_DISPLAY_NAME}
create_catalog_source ${COUCHDB_CATALOG_NAME} ${COUCHDB_CATALOG_IMAGE} ${COUCHDB_CATALOG_DISPLAY_NAME}
create_catalog_source ${COMMON_SERVICES_CATALOG_NAME} ${COMMON_SERVICES_CATALOG_IMAGE} ${COMMON_SERVICES_CATALOG_DISPLAY_NAME}
# create_catalog_source ${DATAPOWER_CATALOG_NAME} ${DATAPOWER_CATALOG_IMAGE}
# create_catalog_source ${EVENT_STREAMS_CATALOG_NAME} ${EVENT_STREAMS_CATALOG_IMAGE}
# create_catalog_source ${ASSET_REPO_CATALOG_NAME} ${ASSET_REPO_CATALOG_IMAGE}
# create_catalog_source ${OPERATIONS_DASHBOARD_CATALOG_NAME} ${OPERATIONS_DASHBOARD_CATALOG_IMAGE}
# create_catalog_source ${NAVIGATOR_CATALOG_NAME} ${NAVIGATOR_CATALOG_IMAGE}
# create_catalog_source ${MQ_CATALOG_NAME} ${MQ_CATALOG_IMAGE}
