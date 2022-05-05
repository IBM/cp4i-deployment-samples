#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
#For restarting the ZenWatcher and ibm-nginx pods
#******************************************************************************

# Namespace needed
# Called by apic
# called by ar

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -c <CALLING_INSTANCE>"
  divider
  exit 1
}

while getopts "n:c:" opt; do
  case ${opt} in
  c)
    CALLING_INSTANCE="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

SCRIPT_DIR=$(dirname $0)

if ! oc get namespace ${NAMESPACE} >/dev/null 2>&1; then
    echo "Namespace not found: ${NAMESPACE}"
    exit 1
fi

PODS_TO_DELETE=$( oc get pod -n ${NAMESPACE} -o name | grep -iw 'zen-watcher\|ibm-nginx')

if [ -z "${PODS_TO_DELETE}" ]; then
    echo -e "[ERROR] zen-watcher and ibm-nginx pods not found"
    exit 1
fi

echo -e "[INFO] Deleting the ${PODS_TO_DELETE}"

if ! oc delete ${PODS_TO_DELETE} -n ${NAMESPACE}; then
    echo -e "[ERROR] Unable to delete the pods ${PODS_TO_DELETE}"
    exit 1
fi 

PODS_TO_RESTART=$( oc get pod -n ${NAMESPACE} -o name | grep -iw 'zen-watcher\|ibm-nginx')


echo -e "[INFO] Waiting for zen-watcher and ibm-nginx pods ${PODS_TO_RESTART} to get ready"

time=0

for POD in ${PODS_TO_RESTART}; do
    echo -e "INFO: Waiting for ${POD} to get ready"
    while [[ "$(oc get ${POD} -n ${NAMESPACE} -o json | jq -r '.status.conditions[] | select(.type=="Ready").status')" != "True" ]]; do
    echo "INFO: $(oc get ${POD} -n ${NAMESPACE})"
    if [ $time -gt 90 ]; then
        echo "ERROR: Exiting ${POD} in ${NAMESPACE} is not ready"
        exit 1
    fi
    echo "INFO: Waiting up to 90 minutes for  ${POD} in ${NAMESPACE} to be ready. Waited ${time} minute(s)."
    time=$((time + 1))
    sleep 60
    done
done
