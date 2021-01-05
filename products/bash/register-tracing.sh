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
#   -a : <apps_namespace> (string), Defaults to "-n namespace"
#
# USAGE:
#   With defaults values
#     ./register-tracing.sh
#
#   Overriding the namespace
#     ./register-tracing -n cp4i-prod
#

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"
apps_namespace=""

SCRIPT_DIR="$(dirname $0)"
echo "Current Dir: $SCRIPT_DIR"

while getopts "n:a:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  a)
    apps_namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [ -z "$apps_namespace" ]; then
  apps_namespace=${namespace}
fi

echo "Registering apps in ${apps_namespace} project for tracing"

echo "Waiting for tracing registration jobs to complete..."
for i in $(seq 1 360); do
  TRACING_JOB_PODS=$(kubectl get pods -n ${apps_namespace} | grep -E '(tracing-reg|odtracing|od-registration)')
  all_completed="true"
  while IFS= read -r line; do
    state=$(echo $line | awk '{print $3}')
    if [ "$state" != "Completed" ]; then
      pod=$(echo $line | awk '{print $1}')
      echo "Waiting for $pod to complete, still in state: $state"
      all_completed="false"
    fi
  done <<<"$TRACING_JOB_PODS"

  if [ "$all_completed" == "true" ]; then
    echo "Tracing registration jobs are complete."
    break
  else
    if [[ i -eq 360 ]]; then
      echo "Timed out waiting for tracing registration jobs to complete"
      exit 1
    fi
    echo "Waiting for tracing registration jobs to complete (Attempt $i of 360)."
    sleep 10
  fi
done

echo "Waiting 1 minute for tracing registration to trickle through"
sleep 60

echo "Waiting for tracing pod..."
# Loop/retry here, tracing pod may not exist yet
JAR=""
for i in $(seq 1 60); do
  OLD_TRACING_POD=$(oc get pod -n ${namespace} -l helm.sh/chart=ibm-icp4i-tracing-prod -o jsonpath='{.items[].metadata.name}' 2>/dev/null)
  if [ $? -ne 0 ]; then
    OLD_TRACING_POD=""
  fi
  NEW_TRACING_POD=$(oc get pod -n ${namespace} -l app.kubernetes.io/name=ibm-integration-operations-dashboard,app.kubernetes.io/component=fe -o jsonpath='{.items[].metadata.name}' 2>/dev/null)
  if [ $? -ne 0 ]; then
    NEW_TRACING_POD=""
  fi

  if [[ -z "$OLD_TRACING_POD" ]] && [[ -z "$NEW_TRACING_POD" ]]; then
    echo "Waiting for tracing pod (Attempt $i of 60), checking again in 15 seconds..."
    sleep 15
  else
    if [[ -z "$OLD_TRACING_POD" ]]; then
      echo "Got new tracing pod: ${NEW_TRACING_POD}"
      JAR=NameSpaceAutoRegistration.2020.3.1.jar
      TRACING_POD=$NEW_TRACING_POD
    else
      echo "Got old tracing pod: ${OLD_TRACING_POD}"
      JAR=NameSpaceAutoRegistration.jar
      TRACING_POD=$OLD_TRACING_POD
    fi
    break
  fi
done
if [[ -z "$TRACING_POD" ]]; then
  echo "Failed to get tracing pod"
  exit 1
fi

echo "Copying ${JAR} into tracing pod..."
# Loop/retry here, pod exists but ui-manager container may not be ready
for i in $(seq 1 60); do
  if oc cp -n ${namespace} ${SCRIPT_DIR}/tracing/${JAR} ${TRACING_POD}:/tmp -c ui-manager; then
    echo "Jar copied"
    break
  else
    if [[ i -eq 60 ]]; then
      echo "Failed to copy jar, giving up after numerous attempts"
      exit 1
    fi
    echo "Failed to copy jar (Attempt $i of 60), trying again in 15 seconds..."
    sleep 15
  fi
done

echo "Running registration jar"
# Loop/retry here, job to request registration may not have run yet
for i in $(seq 1 60); do
  if oc exec -n ${namespace} ${TRACING_POD} -c ui-manager -- java -cp /usr/local/tomee/derby/derbyclient.jar:/tmp/${JAR} org.montier.tracing.demo.NameSpaceAutoRegistration ${apps_namespace} > /tmp/commands.sh; then
    echo "Registration successful"
    break
  else
    if [[ i -eq 60 ]]; then
      echo "Failed to register, giving up after numerous attempts"
      exit 1
    fi
    echo "Failed to register (Attempt $i of 60), trying again in 15 seconds..."
    sleep 15
  fi
done

# test namespace
echo "Creating secret in ${apps_namespace} namespace"
chmod +x /tmp/commands.sh
cd /tmp && ./commands.sh
