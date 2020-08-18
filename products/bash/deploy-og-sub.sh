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
# function usage {
#     echo "Usage: $0 -n <namespace>"
# }
#
namespace="cp4i"

# Get auth port with internal url and apply the operand config in common services namespace
IAM_Update_OperandConfig() {
  export EXTERNAL=$(oc get configmap cluster-info -n kube-system -o jsonpath='{.data.master_public_url}')
  export INT_URL="${EXTERNAL}/.well-known/oauth-authorization-server"
  export IAM_URL=$(curl $INT_URL | jq -r '.issuer')
  echo "INFO: External url: ${EXTERNAL}"
  echo "INFO: INT_URL: ${INT_URL}"
  echo "INFO: IAM URL : ${IAM_URL}"
  echo "INFO: Updating the OperandConfig 'common-service' for IAM Authentication"
  oc get OperandConfig -n ibm-common-services $(oc get OperandConfig -n ibm-common-services | sed -n 2p | awk '{print $1}') -o json | jq '(.spec.services[] | select(.name == "ibm-iam-operator") | .spec.authentication)|={"config":{"roksEnabled":true,"roksURL":"'$IAM_URL'","roksUserPrefix":"IAM#"}}' | oc apply -f -
}

function output_time {
  SECONDS=${1}
  if((SECONDS>59));then
    printf "%d minutes, %d seconds" $((SECONDS/60)) $((SECONDS%60))
  else
    printf "%d seconds" $SECONDS
  fi
}

function wait_for_subscription {
  NAMESPACE=${1}
  NAME=${2}

  phase=""
  time=0
  wait_time=5
  until [[ "$phase" == "Succeeded" ]]; do
    csv=$(oc get subscription -n ${NAMESPACE} ${NAME} -o json | jq -r .status.currentCSV)
    wait=0
    if [[ "$csv" == "null" ]]; then
      echo "Waited for $(output_time $time), not got csv for subscription"
      wait=1
    else
      phase=$(oc get csv -n ${NAMESPACE} $csv -o json | jq -r .status.phase)
      if [[ "$phase" != "Succeeded" ]]; then
        echo "Waited for $(output_time $time), csv not in Succeeded phase, currently: $phase"
        wait=1
      fi
    fi

    if [[ "$wait" == "1" ]]; then
      ((time=time+$wait_time))
      if [ $time -gt 1200 ]; then
        echo "ERROR: Failed after waiting for 20 minutes"
        exit 1
      fi

      sleep $wait_time
    fi
  done
  echo "$NAME has succeeded"
}

function create_subscription {
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

  wait_for_subscription ${NAMESPACE} ${SUBSCRIPTION_NAME}
}

while getopts "n:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

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

# Install common services operator with stable channel
echo "INFO: Applying common services subscription"
create_subscription ${namespace} "opencloud-operators" "ibm-common-service-operator" "stable-v1"
echo "INFO: Common services csv installed, proceeding with installation"

# Wait for upto 10 minutes for the OperandConfig to appear in the common services namespace
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

# Apply the subscription for navigator. This needs to be before apic so apic knows it's running in cp4i
echo "INFO: Applying subscription for platform navigator"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-integration-platform-navigator" "v4.0"

# Applying subscriptions for apic and eventstreams
echo "INFO: Applying subscriptions for ace, apic, eventstreams, and mq"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-apiconnect" "v1.0"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-appconnect" "v1.0"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-eventstreams" "v2.0"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-mq" "v1.1"

# Apply uber operator
echo "INFO: Applying the subscription for the uber operator"
create_subscription ${namespace} "ibm-operator-catalog" "ibm-cp-integration" "v1.0"
echo "INFO: ClusterServiceVersion for the Platform Navigator is now installed, proceeding with installation..."
