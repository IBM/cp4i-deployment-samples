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
#   -n : <namespace> (string), Defaults to "cp4i"
#   -d : Enables deployment of the demos operator
#   -p : Pre_release subscriptions
#   -a : Output alm-examples
#   -e : Extra safe but slow, waits for each operator to complete installing before going on to the next
#
# USAGE:
#   With defaults values
#     ./deploy-og-sub.sh
#
#   Overriding the namespace
#     ./deploy-og-sub.sh -n cp4i-prod
#

function usage() {
  echo "Usage: $0 -n <namespace> -d"
  exit 1
}

namespace="cp4i"
ALM_EXAMPLES=false
DEPLOY_DEMOS=false
EXTRA_SAFE_BUT_SLOW=false

while getopts "n:dae" opt; do
  case ${opt} in
  a)
    ALM_EXAMPLES=true
    ;;
  d)
    DEPLOY_DEMOS=true
    ;;
  e)
    EXTRA_SAFE_BUT_SLOW=true
    ;;
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

# To regenerate the following list install the catalog sources (pre-release if required) using:
#    ./create-catalog-sources.sh -p
# Wait for the catalog sources to install, then run:
# CHANNELS_JSON=$(oc get packagemanifest -o json | jq -r '.items[] | { name: .metadata.name, catalog: .status.catalogSource, channel: .status.channels[-1].name }')
# ENTRIES="NAVIGATOR=ibm-integration-platform-navigator
# ACE=ibm-appconnect
# APIC=ibm-apiconnect
# AR=ibm-integration-asset-repository
# ASPERA=aspera-hsts-operator
# DEMOS=ibm-integration-demos-operator
# DP=datapower-operator
# ES=ibm-eventstreams
# MQ=ibm-mq
# OD=ibm-integration-operations-dashboard"
# for ENTRY in ${ENTRIES} ; do
#   IFS="=" read -r PRODUCT NAME <<< "${ENTRY}"
#   CHANNEL_JSON=$(echo $CHANNELS_JSON | jq -r "select(.name == \"${NAME}\")")
#   CHANNEL=$(echo $CHANNEL_JSON | jq -r ".channel")
#   CATALOG=$(echo $CHANNEL_JSON | jq -r ".catalog")
#   echo "${PRODUCT}_CATALOG=$CATALOG"
#   echo "${PRODUCT}_NAME=$NAME"
#   echo "${PRODUCT}_CHANNEL=$CHANNEL"
# done
NAVIGATOR_CATALOG=ibm-operator-catalog
NAVIGATOR_NAME=ibm-integration-platform-navigator
NAVIGATOR_CHANNEL=v5.1
ACE_CATALOG=ibm-operator-catalog
ACE_NAME=ibm-appconnect
ACE_CHANNEL=v2.0
APIC_CATALOG=ibm-operator-catalog
APIC_NAME=ibm-apiconnect
APIC_CHANNEL=v2.3
AR_CATALOG=ibm-operator-catalog
AR_NAME=ibm-integration-asset-repository
AR_CHANNEL=v1.3
ASPERA_CATALOG=ibm-operator-catalog
ASPERA_NAME=aspera-hsts-operator
ASPERA_CHANNEL=v1.3
DEMOS_CATALOG=cp4i-demo-operator-catalog-source
DEMOS_NAME=ibm-integration-demos-operator
DEMOS_CHANNEL=v1.0
DP_CATALOG=ibm-operator-catalog
DP_NAME=datapower-operator
DP_CHANNEL=v1.4
ES_CATALOG=ibm-operator-catalog
ES_NAME=ibm-eventstreams
ES_CHANNEL=v2.4
MQ_CATALOG=ibm-operator-catalog
MQ_NAME=ibm-mq
MQ_CHANNEL=v1.6
OD_CATALOG=ibm-operator-catalog
OD_NAME=ibm-integration-operations-dashboard
OD_CHANNEL=v2.4

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
    all_succeeded="true"
    subscriptions_succeeded=""
    subscriptions_waiting=""

    rows=$(oc get subscription -n ${NAMESPACE} -o json | jq -r '.items[] | { name: .metadata.name, csv: .status.currentCSV } | @base64')
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

function delete_datapower_subscription() {
  NAMESPACE=${1}

  INSTALL_PLANS=$(oc get installplans -n ${NAMESPACE} | grep "${DP_NAME}" | awk '{print $1}' | xargs)
  if [[ "$INSTALL_PLANS" != "" ]]; then
    echo "About to delete installplans: $INSTALL_PLANS"
    oc delete installplans -n ${NAMESPACE} ${INSTALL_PLANS}
  fi

  CSVS=$(oc get csvs -n ${NAMESPACE} | grep "${DP_NAME}" | awk '{print $1}' | xargs)
  if [[ "$CSVS" != "" ]]; then
    echo "About to delete csvs: $CSVS"
    oc delete csvs -n ${NAMESPACE} ${CSVS}
  fi

  SUBSCRIPTIONS=$(oc get subscriptions -n ${NAMESPACE} | grep "${DP_NAME}" | awk '{print $1}' | xargs)
  if [[ "$SUBSCRIPTIONS" != "" ]]; then
    echo "About to delete subscriptions: $SUBSCRIPTIONS"
    oc delete subscriptions -n ${NAMESPACE} ${SUBSCRIPTIONS}
  fi
}

if [[ "$CLUSTER_SCOPED" != "true" ]]; then
  OPERATOR_GROUP_COUNT=$(oc get operatorgroups -n ${namespace} -o json | jq '.items | length')
  if [[ "${OPERATOR_GROUP_COUNT}" == "0" ]]; then
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
fi

# Create the subscription for navigator. This needs to be before APIC (ibm-apiconnect)
# so APIC knows it's running in CP4I and before tracing (ibm-integration-operations-dashboard)
# as tracing uses a CRD created by the navigator operator.
echo "INFO: Applying subscription for platform navigator"
create_subscription ${namespace} ${NAVIGATOR_CATALOG} "${NAVIGATOR_NAME}" "$NAVIGATOR_CHANNEL"

echo "INFO: Applying subscriptions for aspera, ace, event streams, mq, and asset repo"
create_subscription ${namespace} ${ASPERA_CATALOG} "${ASPERA_NAME}" "${ASPERA_CHANNEL}"
create_subscription ${namespace} ${ACE_CATALOG} "${ACE_NAME}" "${ACE_CHANNEL}"
create_subscription ${namespace} ${ES_CATALOG} "${ES_NAME}" "${ES_CHANNEL}"
create_subscription ${namespace} ${MQ_CATALOG} "${MQ_NAME}" "${MQ_CHANNEL}"
create_subscription ${namespace} ${AR_CATALOG} "${AR_NAME}" "${AR_CHANNEL}"

if [[ "${DEPLOY_DEMOS}" == "true" ]]; then
  echo "INFO: Applying subscription for demos"
  create_subscription ${namespace} ${DEMOS_CATALOG} "${DEMOS_NAME}" "${DEMOS_CHANNEL}"
fi

if [[ "${EXTRA_SAFE_BUT_SLOW}" == "false" ]]; then
  echo "INFO: Wait for platform navigator before applying the APIC/Tracing subscriptions"
  wait_for_subscription ${namespace} ${NAVIGATOR_CATALOG} "${NAVIGATOR_NAME}" "$NAVIGATOR_CHANNEL"
fi

echo "INFO: Apply the APIC/Tracing subscriptions"
create_subscription ${namespace} ${APIC_CATALOG} "${APIC_NAME}" "${APIC_CHANNEL}"
create_subscription ${namespace} ${OD_CATALOG} "${OD_NAME}" "${OD_CHANNEL}"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions ${namespace}

if [[ "${ALM_EXAMPLES}" == "true" ]]; then
  SOURCE_NAMESPACE="openshift-marketplace"

  SUBSCRIPTION_NAME="${NAVIGATOR_NAME}-${NAVIGATOR_CHANNEL}-${NAVIGATOR_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  nav_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="PlatformNavigator")]')
  echo "###################################"
  echo "# Examples for release-navigator.sh"
  echo "###################################"
  echo $nav_examples | yq r -P -

  SUBSCRIPTION_NAME="${ACE_NAME}-${ACE_CHANNEL}-${ACE_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  ace_dashboard_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="Dashboard")]')
  ace_dashboard_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="Dashboard") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  ace_designer_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="DesignerAuthoring")]')
  ace_designer_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="DesignerAuthoring") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  ace_integration_server_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="IntegrationServer")]')
  ace_integration_server_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="IntegrationServer") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  echo ""
  echo "#######################################"
  echo "# Examples for release-ace-dashboard.sh"
  echo "#######################################"
  echo $ace_dashboard_examples | yq r -P -
  echo "#######################################"
  echo "# Versions for release-ace-dashboard.sh"
  echo "#######################################"
  echo $ace_dashboard_versions | yq r -P -
  echo ""
  echo "######################################"
  echo "# Examples for release-ace-designer.sh"
  echo "######################################"
  echo $ace_designer_examples | yq r -P -
  echo "######################################"
  echo "# Versions for release-ace-designer.sh"
  echo "######################################"
  echo $ace_designer_versions | yq r -P -
  echo ""
  echo "################################################"
  echo "# Examples for release-ace-integration-server.sh"
  echo "################################################"
  echo $ace_integration_server_examples | yq r -P -
  echo "################################################"
  echo "# Versions for release-ace-integration-server.sh"
  echo "################################################"
  echo $ace_integration_server_versions | yq r -P -

  SUBSCRIPTION_NAME="${APIC_NAME}-${APIC_CHANNEL}-${APIC_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  apic_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="APIConnectCluster")]')
  apic_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="APIConnectCluster") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  echo ""
  echo "##############################"
  echo "# Examples for release-apic.sh"
  echo "##############################"
  echo $apic_examples | yq r -P -
  echo "##############################"
  echo "# Versions for release-apic.sh"
  echo "##############################"
  echo $apic_versions | yq r -P -

  SUBSCRIPTION_NAME="${AR_NAME}-${AR_CHANNEL}-${AR_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  ar_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="AssetRepository")]')
  ar_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="AssetRepository") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  echo ""
  echo "############################"
  echo "# Examples for release-ar.sh"
  echo "############################"
  echo $ar_examples | yq r -P -
  echo "############################"
  echo "# Versions for release-ar.sh"
  echo "############################"
  echo $ar_versions | yq r -P -

  SUBSCRIPTION_NAME="${ES_NAME}-${ES_CHANNEL}-${ES_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  es_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="EventStreams")]')
  es_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="EventStreams") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  echo ""
  echo "############################"
  echo "# Examples for release-es.sh"
  echo "############################"
  echo $es_examples | yq r -P -
  echo "############################"
  echo "# Versions for release-es.sh"
  echo "############################"
  echo $es_versions | yq r -P -

  SUBSCRIPTION_NAME="${MQ_NAME}-${MQ_CHANNEL}-${MQ_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  mq_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="QueueManager")]')
  # mq_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="QueueManager") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  mq_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="QueueManager") | .specDescriptors[] | select(.path=="version") | .description')
  echo ""
  echo "############################"
  echo "# Examples for release-mq.sh"
  echo "############################"
  echo $mq_examples | yq r -P -
  echo "############################"
  echo "# Versions for release-mq.sh"
  echo "############################"
  echo $mq_versions

  SUBSCRIPTION_NAME="${OD_NAME}-${OD_CHANNEL}-${OD_CATALOG}-${SOURCE_NAMESPACE}"
  csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
  od_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="OperationsDashboard")]')
  od_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="OperationsDashboard") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
  echo ""
  echo "#################################"
  echo "# Examples for release-tracing.sh"
  echo "#################################"
  echo $od_examples | yq r -P -
  echo "#################################"
  echo "# Versions for release-tracing.sh"
  echo "#################################"
  echo $od_versions | yq r -P -
fi
