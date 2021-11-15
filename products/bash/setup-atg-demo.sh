#!/bin/bash -e
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# https://apiconnect-jenkins.swg-devops.com/job/velox-integration/job/apiconnect-operator/job/v10.0/2059/
DP_CATALOG_SOURCE=ibmcom/datapower-operator-catalog@sha256:381c3a7274d36d41177a81a0e5f05a16ec9d0232b1f3773a88a6a0398c938ce3
APIC_CATALOG_SOURCE=ibmcom/ibm-apiconnect-catalog@sha256:d2198a8f8b1f54d3bda0277815008bdc27bc7a11b72fc67cf17b7d2231f6ac16

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 [-a <APIC catalog source image>] [-d <DataPower catalog source image>] [-n <namespace>] [-f <file storage class>]"
  divider
  exit 1
}

namespace=cp4i
SCRIPT_DIR=$(dirname $0)
release_name=ademo
DEFAULT_FILE_STORAGE="ibmc-file-gold-gid"

while getopts "a:d:n:f:" opt; do
  case ${opt} in
  a)
    APIC_CATALOG_SOURCE="$OPTARG"
    ;;
  d)
    DP_CATALOG_SOURCE="$OPTARG"
    ;;
  f)
    DEFAULT_FILE_STORAGE="$OPTARG"
    ;;
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  # image: docker.io/ibmcom/ibm-common-service-catalog:latest
  image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:latest-validated
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: automation-base-pak-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMABP Operators
  image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:latest-validated
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: pn-operators
  namespace: openshift-marketplace
spec:
  displayName: PN Operators
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-ai-wmltraining-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
  updateStrategy:
    registryPoll:
      interval: 45m
---
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: dp-operator
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${DP_CATALOG_SOURCE}
  displayName: DataPower
  publisher: IBM
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
  displayName: IBM APIConnect catalog
  image: ${APIC_CATALOG_SOURCE}
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

function output_time() {
  SECONDS=${1}
  if ((SECONDS > 59)); then
    printf "%d minutes, %d seconds" $((SECONDS / 60)) $((SECONDS % 60))
  else
    printf "%d seconds" $SECONDS
  fi
}

function wait_for_subscription_with_timeout() {
  NAMESPACE=${1}
  SOURCE=${2}
  NAME=${3}
  CHANNEL=${4}
  TIMEOUT_SECONDS=${5}
  SOURCE_NAMESPACE="openshift-marketplace"

  SUBSCRIPTION_NAME="${NAME}-${CHANNEL}-${SOURCE}-${SOURCE_NAMESPACE}"

  echo "Waiting for subscription \"${SUBSCRIPTION_NAME}\" in namespace \"${NAMESPACE}\""

  phase=""
  time=0
  wait_time=5
  until [[ "$phase" == "Succeeded" ]]; do
    csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
    wait=0
    if [[ "$csv" == "null" ]]; then
      echo "  ${SUBSCRIPTION_NAME}: Not got csv"
      wait=1
    else
      phase=$(oc get csv -n ${NAMESPACE} $csv -o json 2>/dev/null | jq -r .status.phase)
      if [[ "$phase" != "Succeeded" ]]; then
        echo "  ${SUBSCRIPTION_NAME}: CSV \"$csv\" in phase \"${phase}\""
        wait=1
      fi
    fi

    if [[ "$wait" == "1" ]]; then
      if [ $time -ge ${TIMEOUT_SECONDS} ]; then
        echo "ERROR: Failed after waiting for $(($TIMEOUT_SECONDS / 60)) minutes"
        export wait_for_subscription_with_timeout_result=1
        return 1
      fi

      echo "Retrying in ${wait_time} seconds, waited for $(output_time $time) so far"
      ((time = time + $wait_time))
      sleep $wait_time
    fi
  done
  echo "$SUBSCRIPTION_NAME has succeeded"
  export wait_for_subscription_with_timeout_result=0
  return 0
}

function wait_for_subscription() {
  wait_for_subscription_with_timeout ${1} ${2} ${3} ${4} 7200
  if [[ "${wait_for_subscription_with_timeout_result}" != "0" ]]; then
    exit ${wait_for_subscription_with_timeout_result}
  fi
}

function wait_for_all_subscriptions() {
  NAMESPACE=${1}
  echo "Waiting for all subscriptions in namespace: $NAMESPACE"

  all_succeeded="false"
  time=0
  wait_time=5
  until [[ "$all_succeeded" == "true" ]]; do
    subscriptions_succeeded=""
    subscriptions_waiting=""

    rows=$(oc get subscription -n ${NAMESPACE} -o json | jq -r '.items[] | { name: .metadata.name, csv: .status.currentCSV } | @base64')
    if [[ "$rows" != "" ]]; then
      all_succeeded="true"
    fi
    for row in $rows; do
      _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
      }

      SUBSCRIPTION_NAME=$(_jq '.name')
      csv=$(_jq '.csv')

      if [[ "$csv" == "null" ]]; then
        all_succeeded="false"
        subscriptions_waiting="${subscriptions_waiting}\n    ${SUBSCRIPTION_NAME}: Not got csv"
      else
        phase=$(oc get csv -n ${NAMESPACE} $csv -o json 2>/dev/null | jq -r .status.phase)
        if [[ "$phase" != "Succeeded" ]]; then
          subscriptions_waiting="${subscriptions_waiting}\n    ${SUBSCRIPTION_NAME}: CSV \"$csv\" in phase \"${phase}\""
          all_succeeded="false"
        else
          subscriptions_succeeded="${subscriptions_succeeded}\n    ${SUBSCRIPTION_NAME}"
        fi
      fi
    done

    if [[ ! -z "$subscriptions_succeeded" ]]; then
      echo -e "  The following subscriptions have succeeded:${subscriptions_succeeded}"
    fi
    if [[ ! -z "$subscriptions_waiting" ]]; then
      echo -e "  Still waiting for the following subscriptions:${subscriptions_waiting}"
    fi

    if [[ "$all_succeeded" == "false" ]]; then
      if [ $time -ge 7200 ]; then
        echo "ERROR: Failed after waiting for 120 minutes"
        exit 1
      fi

      echo "Retrying in ${wait_time} seconds, waited for $(output_time $time) so far"
      ((time = time + $wait_time))
      sleep $wait_time
    fi

  done

  echo "All subscriptions in $NAMESPACE have succeeded"
}

function create_subscription() {
  NAMESPACE=${1}
  SOURCE=${2}
  NAME=${3}
  CHANNEL=${4}
  SOURCE_NAMESPACE="openshift-marketplace"

  SUBSCRIPTION_NAME="${NAME}-${CHANNEL}-${SOURCE}-${SOURCE_NAMESPACE}"

  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${SUBSCRIPTION_NAME}
  namespace: ${NAMESPACE}
spec:
  channel: ${CHANNEL}
  installPlanApproval: Automatic
  name: ${NAME}
  source: ${SOURCE}
  sourceNamespace: ${SOURCE_NAMESPACE}
EOF

  if [[ "${EXTRA_SAFE_BUT_SLOW}" == "true" ]]; then
    wait_for_subscription ${NAMESPACE} ${SOURCE} "${NAME}" "${CHANNEL}"
  fi
}


# To regenerate the following list install the above catalog sources:
#    ./create-catalog-sources.sh -p
# Wait for the catalog sources to install, then run:
# CHANNELS_JSON=$(oc get packagemanifest -o json | jq -r '.items[] | { name: .metadata.name, catalog: .status.catalogSource, channel: .status.channels[-1].name }')
# ENTRIES="NAVIGATOR=ibm-integration-platform-navigator
# APIC=ibm-apiconnect"
# for ENTRY in ${ENTRIES} ; do
#   IFS="=" read -r PRODUCT NAME <<< "${ENTRY}"
#   CHANNEL_JSON=$(echo $CHANNELS_JSON | jq -r "select(.name == \"${NAME}\")")
#   CHANNEL=$(echo $CHANNEL_JSON | jq -r ".channel")
#   CATALOG=$(echo $CHANNEL_JSON | jq -r ".catalog")
#   echo "${PRODUCT}_CATALOG=$CATALOG"
#   echo "${PRODUCT}_NAME=$NAME"
#   echo "${PRODUCT}_CHANNEL=$CHANNEL"
# done
NAVIGATOR_CATALOG=pn-operators
NAVIGATOR_NAME=ibm-integration-platform-navigator
NAVIGATOR_CHANNEL=v5.2
APIC_CATALOG=ibm-apiconnect-catalog
APIC_NAME=ibm-apiconnect
APIC_CHANNEL=v2.4

ELASTIC_NAMESPACE=openshift-operators-redhat
ELASTIC_CATALOG=redhat-operators
ELASTIC_NAME=elasticsearch-operator
ELASTIC_CHANNEL=stable

JAEGER_NAMESPACE=openshift-operators
JAEGER_CATALOG=redhat-operators
JAEGER_NAME=jaeger-product
JAEGER_CHANNEL=stable

if ! oc get namespace ${namespace}; then
  oc create namespace ${namespace}
fi

if [[ "$(oc get operatorgroup -n ${namespace} -o json | jq -r '.items | length')" == "0" ]]; then
  echo "Setup the OperatorGroup for ${namespace} namespace"
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${namespace}-og
  namespace: ${namespace}
spec:
  targetNamespaces:
    - ${namespace}
EOF
fi

if ! oc get namespace openshift-operators-redhat; then
  oc create namespace openshift-operators-redhat
fi

if [[ "$(oc get operatorgroup -n openshift-operators-redhat -o json | jq -r '.items | length')" == "0" ]]; then
  echo "Setup the OperatorGroup for openshift-operators-redhat namespace"
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  namespace: openshift-operators-redhat
  name: openshift-operators-redhat-og
EOF
fi

echo "INFO: Apply the Navigator subscription"
create_subscription ${namespace} ${NAVIGATOR_CATALOG} "${NAVIGATOR_NAME}" "$NAVIGATOR_CHANNEL"

echo "Apply subscriptions for Elastic Search/Jaeger"
create_subscription ${ELASTIC_NAMESPACE} ${ELASTIC_CATALOG} "${ELASTIC_NAME}" "${ELASTIC_CHANNEL}"
create_subscription ${JAEGER_NAMESPACE} ${JAEGER_CATALOG} "${JAEGER_NAME}" "${JAEGER_CHANNEL}"

if [[ "${EXTRA_SAFE_BUT_SLOW}" != "false" ]]; then
  echo "INFO: Wait for Navigator before applying the APIC subscription"
  wait_for_subscription ${namespace} ${NAVIGATOR_CATALOG} "${NAVIGATOR_NAME}" "$NAVIGATOR_CHANNEL"
fi

echo "INFO: Apply the APIC subscription"
create_subscription ${namespace} ${APIC_CATALOG} "${APIC_NAME}" "${APIC_CHANNEL}"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions ${namespace}
wait_for_all_subscriptions ${ELASTIC_NAMESPACE}
wait_for_all_subscriptions ${JAEGER_NAMESPACE}

echo "Install Nav"
cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: ${namespace}-navigator
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
  mqDashboard: true
  replicas: 1
  version: 2021.4.1
  storage:
    class: ${DEFAULT_FILE_STORAGE}
EOF

echo "Install Jaeger"
cat <<EOF | oc apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  namespace: ${namespace}
  name: jaeger-bookshop
spec:
  strategy: production
  storage:
    type: elasticsearch
  ingress:
    security: oauth-proxy
EOF

# TODO Wait for Jaeger?

echo "Install Bookshop server"
${SCRIPT_DIR}/../../TestgenBookshopAPI/service/scripts/deploy.sh -n ${namespace}

echo "Install APIC"
cat <<EOF | oc apply -f -
apiVersion: apiconnect.ibm.com/v1beta1
kind: APIConnectCluster
metadata:
  name: ${release_name}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/instance: apiconnect
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: apiconnect-production
spec:
  version: 10.0.4
  license:
    accept: true
    use: nonproduction
    license: L-RJON-C7BJ42
  profile: n1xc7.m48
  gateway:
    jaegerTracing:
      jaegerCollectorEndpoint: jaeger-bookshop-collector:14250
      agentImage: jaegertracing/jaeger-agent:latest
      samplingType: ratelimiting
      samplingRate: "25"
      tls:
        collectorEndpoint:
          secretName: jaeger-bookshop-collector-headless-tls
          serverName: jaeger-bookshop-collector-headless.${namespace}.svc.cluster.local
        disabled: false
        skipHostVerify: false
    replicaCount: 1
  management:
    testAndMonitor:
      enabled: true
      aiEnabled: true
      jaegerEndpoint: >-
        jaeger-bookshop-query-api.${namespace}.svc:16685
EOF

echo "Setup APIC for ATG"
$SCRIPT_DIR/configure-apic-atg.sh -n ${namespace} -r ${release_name}
