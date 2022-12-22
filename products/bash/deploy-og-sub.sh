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

      $CURRENT_DIR/fixup-olm.sh -n $namespace

      echo "Retrying in ${wait_time} seconds, waited for $(output_time $time) so far"
      ((time = time + $wait_time))
      sleep $wait_time
    fi
  done

  echo -e "All subscriptions in $NAMESPACE have succeeded:${subscriptions_succeeded}"
}

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
fi

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator-ibm-common-service-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: ibm-common-service-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cloud-databases-redis-operator-ibm-cloud-databases-redis-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-cloud-databases-redis-operator
  source: ibm-cloud-databases-redis-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-platform-navigator-ibm-integration-platform-navigator-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-integration-platform-navigator
  source: ibm-integration-platform-navigator-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: aspera-hsts-operator-aspera-hsts-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: aspera-hsts-operator
  source: aspera-hsts-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-appconnect-appconnect-operator-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-appconnect
  source: appconnect-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-eventstreams-ibm-eventstreams-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-eventstreams
  source: ibm-eventstreams-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-mq-ibm-mq-operator-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-mq
  source: ibm-mq-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-asset-repository-ibm-integration-asset-repository-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-integration-asset-repository
  source: ibm-integration-asset-repository-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: datapower-operator-datapower-operator-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: datapower-operator
  source: datapower-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-apiconnect-ibm-apiconnect-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-apiconnect
  source: ibm-apiconnect-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"

YAML=$(cat <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-operations-dashboard-ibm-integration-operations-dashboard-catalog-openshift-marketplace
spec:
  installPlanApproval: Automatic
  name: ibm-integration-operations-dashboard
  source: ibm-integration-operations-dashboard-catalog
  sourceNamespace: openshift-marketplace
EOF
)
echo "namespace=$namespace"
OCApplyYAML "$namespace" "$YAML"

echo "INFO: Wait for all subscriptions to succeed"
wait_for_all_subscriptions "${namespace}"
