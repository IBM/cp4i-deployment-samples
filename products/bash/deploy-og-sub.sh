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
#     ./deploy-og-sub.sh -n cp4i-prod
#

#SLOW_BUT_SAFE="true"

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
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

function output_time() {
  SECONDS=${1}
  if ((SECONDS > 59)); then
    printf "%d minutes, %d seconds" $((SECONDS / 60)) $((SECONDS % 60))
  else
    printf "%d seconds" $SECONDS
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
    if [ $? -ne 0 ]; then
      continue
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

  echo -e "All subscriptions in $NAMESPACE have succeeded:${subscriptions_succeeded}"
}

CERT_MANAGER_NAMESPACE="cert-manager-operator"
if oc get namespace $CERT_MANAGER_NAMESPACE >/dev/null 2>&1; then
  echo -e "$INFO [INFO] namespace $CERT_MANAGER_NAMESPACE already exists"
else
  echo -e "$INFO [INFO] Creating the '$CERT_MANAGER_NAMESPACE' namespace\n"
  if ! oc create namespace $CERT_MANAGER_NAMESPACE; then
    echo -e "$CROSS [ERROR] Failed to create the '$CERT_MANAGER_NAMESPACE' namespace"
    divider
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Successfully created the '$CERT_MANAGER_NAMESPACE' namespace"
  fi
fi

if [[ "$CLUSTER_SCOPED" != "true" ]]; then
  OPERATOR_GROUP_COUNT=$(oc get operatorgroups -n ${namespace} -o json | jq '.items | length')
  if [[ "${OPERATOR_GROUP_COUNT}" == "0" ]]; then
    YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${namespace}-og
  namespace: ${namespace}
spec:
  targetNamespaces:
    - ${namespace}
EOF
)
    OCApplyYAML "$namespace" "$YAML"
  fi
  OPERATOR_GROUP_COUNT=$(oc get operatorgroups -n ${CERT_MANAGER_NAMESPACE} -o json | jq '.items | length')
  if [[ "${OPERATOR_GROUP_COUNT}" == "0" ]]; then
    YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${CERT_MANAGER_NAMESPACE}-og
  namespace: ${CERT_MANAGER_NAMESPACE}
spec:
  targetNamespaces:
    - ${CERT_MANAGER_NAMESPACE}
EOF
)
    OCApplyYAML "$CERT_MANAGER_NAMESPACE" "$YAML"
  fi
fi

CERT_MANAGER_YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
spec:
  channel: stable-v1
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
)
OCApplyYAML "$CERT_MANAGER_NAMESPACE" "$CERT_MANAGER_YAML"

ALL_YAMLS=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-platform-navigator-ibm-integration-platform-navigator-catalog-openshift-marketplace
spec:
  channel: v7.3-sc2
  installPlanApproval: Automatic
  name: ibm-integration-platform-navigator
  source: ibm-integration-platform-navigator-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: aspera-hsts-operator-aspera-operators-openshift-marketplace
spec:
  channel: v1.5
  installPlanApproval: Automatic
  name: aspera-hsts-operator
  source: aspera-operators
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-appconnect-appconnect-operator-catalogsource-openshift-marketplace
spec:
  channel: v12.0-sc2
  installPlanApproval: Automatic
  name: ibm-appconnect
  source: appconnect-operator-catalogsource
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-eventstreams-ibm-eventstreams-openshift-marketplace
spec:
  channel: v3.5
  installPlanApproval: Automatic
  name: ibm-eventstreams
  source: ibm-eventstreams
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-mq-ibmmq-operator-catalogsource-openshift-marketplace
spec:
  channel: v3.2-sc2
  installPlanApproval: Automatic
  name: ibm-mq
  source: ibmmq-operator-catalogsource
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-asset-repository-ibm-integration-asset-repository-catalog-openshift-marketplace
spec:
  channel: v1.7-sc2
  installPlanApproval: Automatic
  name: ibm-integration-asset-repository
  source: ibm-integration-asset-repository-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: datapower-operator-ibm-datapower-operator-catalog-openshift-marketplace
spec:
  channel: v1.11-sc2
  installPlanApproval: Automatic
  name: datapower-operator
  source: ibm-datapower-operator-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-apiconnect-ibm-apiconnect-catalog-openshift-marketplace
spec:
  channel: v5.3-sc2
  installPlanApproval: Automatic
  name: ibm-apiconnect
  source: ibm-apiconnect-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-eventendpointmanagement-ibm-eventendpointmanagement-catalog-openshift-marketplace
spec:
  channel: v11.4
  installPlanApproval: Automatic
  name: ibm-eventendpointmanagement
  source: ibm-eventendpointmanagement-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
spec:
  channel: v4.6
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
---
# NOTE Leave the above "---" there to make SLOW_BUT_SAFE apply the last subscription
EOF
)

echo "namespace=$namespace"

if [[ "$SLOW_BUT_SAFE" == "true" ]]; then
  CURRENT_YAML=""
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      OCApplyYAML "$namespace" "$CURRENT_YAML"

      echo "INFO: Wait for all subscriptions to succeed"
      wait_for_all_subscriptions "${namespace}"

      CURRENT_YAML=""
    else
      CURRENT_YAML="${CURRENT_YAML}
${line}"
    fi
  done <<< "$ALL_YAMLS"
else
  OCApplyYAML "$namespace" "$ALL_YAMLS"

  echo "INFO: Wait for all subscriptions to succeed"
  wait_for_all_subscriptions "${namespace}"
fi 
