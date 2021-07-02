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
#
# USAGE:
#   With defaults values
#     ./deploy-og-sub.sh
#
#   Overriding the namespace
#     ./deploy-og-sub.sh -n cp4i-prod
#

function usage() {
  echo "Usage: $0 -n <namespace> -d -p"
  exit 1
}

namespace="cp4i"
DEPLOY_DEMOS=false
pre_release=false

while getopts "n:dp" opt; do
  case ${opt} in
  d)
    DEPLOY_DEMOS=true
    ;;
  n)
    namespace="$OPTARG"
    ;;
  p)
    pre_release=true
    ;;
  \?)
    usage
    ;;
  esac
done

STAGING_AUTHS=$(oc get secret --namespace ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths["cp.stg.icr.io"]')
if [[ "$STAGING_AUTHS" == "" || "$STAGING_AUTHS" == "null" ]]; then
  USE_PRERELEASE_CATALOGS=false
else
  USE_PRERELEASE_CATALOGS=true
fi

if [[ "${USE_PRERELEASE_CATALOGS}" == "true" ]]; then
  NAVIGATOR_CATALOG="pn-operators"
  ACE_CATALOG="ace-operators"
  AR_CATALOG="ar-operators"
  OD_CATALOG="od-operators"
  APIC_CATALOG="apic-operators"
  ASPERA_CATALOG="aspera-operators"
  DP_CATALOG="dp-operators"
  ES_CATALOG="es-operators"
  MQ_CATALOG="mq-operators"
  DEMOS_CATALOG="cp4i-demo-operator-catalog-source"
else
  NAVIGATOR_CATALOG="ibm-operator-catalog"
  ACE_CATALOG="ibm-operator-catalog"
  AR_CATALOG="ibm-operator-catalog"
  OD_CATALOG="ibm-operator-catalog"
  APIC_CATALOG="ibm-operator-catalog"
  ASPERA_CATALOG="ibm-operator-catalog"
  DP_CATALOG="ibm-operator-catalog"
  ES_CATALOG="ibm-operator-catalog"
  MQ_CATALOG="ibm-operator-catalog"
  DEMOS_CATALOG="cp4i-demo-operator-catalog-source"
fi

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
}

function delete_datapower_subscription() {
  NAMESPACE=${1}

  INSTALL_PLANS=$(oc get installplans -n ${NAMESPACE} | grep "datapower-operator" | awk '{print $1}' | xargs)
  if [[ "$INSTALL_PLANS" != "" ]]; then
    echo "About to delete installplans: $INSTALL_PLANS"
    oc delete installplans -n ${NAMESPACE} ${INSTALL_PLANS}
  fi

  CSVS=$(oc get csvs -n ${NAMESPACE} | grep "datapower-operator" | awk '{print $1}' | xargs)
  if [[ "$CSVS" != "" ]]; then
    echo "About to delete csvs: $CSVS"
    oc delete csvs -n ${NAMESPACE} ${CSVS}
  fi

  SUBSCRIPTIONS=$(oc get subscriptions -n ${NAMESPACE} | grep "datapower-operator" | awk '{print $1}' | xargs)
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
if [[ "${pre_release}" == "true" ]]; then
  create_subscription ${namespace} ${NAVIGATOR_CATALOG} "ibm-integration-platform-navigator" "v5.0"
  wait_for_subscription ${namespace} ${NAVIGATOR_CATALOG} "ibm-integration-platform-navigator" "v5.0"
  create_subscription ${namespace} ${ASPERA_CATALOG} "aspera-hsts-operator" "v1.2-eus"
  wait_for_subscription ${namespace} ${ASPERA_CATALOG} "aspera-hsts-operator" "v1.2-eus"
  create_subscription ${namespace} ${ACE_CATALOG} "ibm-appconnect" "v1.5"
  wait_for_subscription ${namespace} ${ACE_CATALOG} "ibm-appconnect" "v1.5"
  create_subscription ${namespace} ${ES_CATALOG} "ibm-eventstreams" "v2.3"
  wait_for_subscription ${namespace} ${ES_CATALOG} "ibm-eventstreams" "v2.3"
  create_subscription ${namespace} ${MQ_CATALOG} "ibm-mq" "v1.5"
  wait_for_subscription ${namespace} ${MQ_CATALOG} "ibm-mq" "v1.5"
  create_subscription ${namespace} ${AR_CATALOG} "ibm-integration-asset-repository" "v1.3"
  wait_for_subscription ${namespace} ${AR_CATALOG} "ibm-integration-asset-repository" "v1.3"
else
  create_subscription ${namespace} ${NAVIGATOR_CATALOG} "ibm-integration-platform-navigator" "v5.0"
  wait_for_subscription ${namespace} ${NAVIGATOR_CATALOG} "ibm-integration-platform-navigator" "v5.0"
  create_subscription ${namespace} ${ASPERA_CATALOG} "aspera-hsts-operator" "v1.2-eus"
  wait_for_subscription ${namespace} ${ASPERA_CATALOG} "aspera-hsts-operator" "v1.2-eus"
  create_subscription ${namespace} ${ACE_CATALOG} "ibm-appconnect" "v1.5"
  wait_for_subscription ${namespace} ${ACE_CATALOG} "ibm-appconnect" "v1.5"
  create_subscription ${namespace} ${ES_CATALOG} "ibm-eventstreams" "v2.3"
  wait_for_subscription ${namespace} ${ES_CATALOG} "ibm-eventstreams" "v2.3"
  create_subscription ${namespace} ${MQ_CATALOG} "ibm-mq" "v1.5"
  wait_for_subscription ${namespace} ${MQ_CATALOG} "ibm-mq" "v1.5"
  create_subscription ${namespace} ${AR_CATALOG} "ibm-integration-asset-repository" "v1.3"
  wait_for_subscription ${namespace} ${AR_CATALOG} "ibm-integration-asset-repository" "v1.3"
fi

if [[ "${DEPLOY_DEMOS}" == "true" ]]; then
  create_subscription ${namespace} ${DEMOS_CATALOG} "ibm-integration-demos-operator" "v1.0"
  wait_for_subscription ${namespace} ${DEMOS_CATALOG} "ibm-integration-demos-operator" "v1.0"
fi

# echo "INFO: Wait for platform navigator before applying the APIC/Tracing subscriptions"
# wait_for_subscription ${namespace} ${NAVIGATOR_CATALOG} "ibm-integration-platform-navigator" "v4.2"
echo "INFO: ClusterServiceVersion for the Platform Navigator is now installed, proceeding with installation..."

echo "INFO: Apply the APIC/Tracing subscriptions"
if [[ "${pre_release}" == "true" ]]; then
  create_subscription ${namespace} ${APIC_CATALOG} "ibm-apiconnect" "v2.3"
  create_subscription ${namespace} ${OD_CATALOG} "ibm-integration-operations-dashboard" "v2.3"
else
  create_subscription ${namespace} ${APIC_CATALOG} "ibm-apiconnect" "v2.3"
  create_subscription ${namespace} ${OD_CATALOG} "ibm-integration-operations-dashboard" "v2.3"
fi

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions ${namespace}
