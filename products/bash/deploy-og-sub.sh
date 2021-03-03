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
#
# USAGE:
#   With defaults values
#     ./deploy-og-sub.sh
#
#   Overriding the namespace
#     ./deploy-og-sub -n cp4i-prod
#

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"

while getopts "n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

# Get auth port with internal url and apply the operand config in common services namespace
IAM_Update_OperandConfig() {
  export EXTERNAL=$(oc get configmap cluster-info -n kube-system -o jsonpath='{.data.master_public_url}')
  export INT_URL="${EXTERNAL}/.well-known/oauth-authorization-server"
  export IAM_URL=$(curl $INT_URL 2>/dev/null | jq -r '.issuer')
  echo "INFO: External url: ${EXTERNAL}"
  echo "INFO: INT_URL: ${INT_URL}"
  echo "INFO: IAM URL : ${IAM_URL}"
  echo "INFO: Updating the OperandConfig 'common-service' for IAM Authentication"
  oc get OperandConfig -n ibm-common-services $(oc get OperandConfig -n ibm-common-services | sed -n 2p | awk '{print $1}') -o json | jq '(.spec.services[] | select(.name == "ibm-iam-operator") | .spec.authentication)|={"config":{"roksEnabled":true,"roksURL":"'$IAM_URL'","roksUserPrefix":"IAM#"}}' | oc apply -f -
}

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
        echo "ERROR: Failed after waiting for $(($TIMEOUT_SECONDS/60)) minutes"
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

# Create the subscription for navigator. This needs to be before APIC (ibm-apiconnect)
# so APIC knows it's running in CP4I and before tracing (ibm-integration-operations-dashboard)
# as tracing uses a CRD created by the navigator operator.
echo "INFO: Applying subscription for platform navigator"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-integration-platform-navigator" "v4.1-eus"

echo "INFO: Applying individual subscriptions for CP4I dependencies"
create_subscription ${namespace} "certified-operators" "couchdb-operator-certified" "v1.4"
create_subscription ${namespace} "ibm-operator-catalog" "aspera-hsts-operator" "v1.2-eus"

create_subscription ${namespace} "ibm-operator-catalog" "ibm-appconnect" "v1.1-eus"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-eventstreams" "v2.2-eus"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-mq" "v1.3-eus"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-integration-asset-repository" "v1.1-eus"

echo "INFO: Wait for platform navigator before applying the APIC/Tracing subscriptions"
wait_for_subscription ${namespace} "ibm-operator-catalog" "ibm-integration-platform-navigator" "v4.1-eus"
echo "INFO: ClusterServiceVersion for the Platform Navigator is now installed, proceeding with installation..."

echo "INFO: Apply the APIC/Tracing subscriptions"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-apiconnect" "v2.1-eus"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-integration-operations-dashboard" "v2.1-eus"

echo "Wait for the APIC operator to succeed"
wait_for_subscription ${namespace} "ibm-operator-catalog" "ibm-apiconnect" "v2.1-eus"

echo "Keep retrying the datapower operator"
wait_for_subscription_with_timeout ${namespace} "ibm-operator-catalog" "datapower-operator" "v1.2-eus" 300
while [[ "${wait_for_subscription_with_timeout_result}" != "0" ]]; do
  delete_datapower_subscription ${namespace}
  create_subscription ${namespace} "ibm-operator-catalog" "datapower-operator" "v1.2-eus"
  wait_for_subscription_with_timeout ${namespace} "ibm-operator-catalog" "datapower-operator" "v1.2-eus" 300
done

# echo "INFO: Applying the subscription for the uber operator"
# create_subscription ${namespace} "ibm-operator-catalog" "ibm-cp-integration" "v1.1-eus"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions ${namespace}

if [[ $(echo "$CLUSTER_TYPE" | tr '[:upper:]' '[:lower:]') == "roks" ]]; then
  # Wait for up to 10 minutes for the OperandConfig to appear in the common services namespace for a ROKS cluster
  time=0
  while [ "$(oc get OperandConfig -n ibm-common-services | sed -n 2p | awk '{print $1}')" != "common-service" ]; do
    if [ $time -gt 10 ]; then
      echo "ERROR: Exiting installation as OperandConfig 'common-services is not found'"
      exit 1
    fi
    echo "INFO: Waiting up to 10 minutes for OperandConfig 'common-services' to be available. Waited ${time} minute(s)."
    time=$((time + 1))
    sleep 60
  done
  echo "INFO: Operand config common-services found: $(oc get OperandConfig -n ibm-common-services | sed -n 2p | awk '{print $1}')"
  echo "INFO: Proceeding with updating the OperandConfig to enable Openshift Authentication..."
  IAM_Update_OperandConfig
fi
