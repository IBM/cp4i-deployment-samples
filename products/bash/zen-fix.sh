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
  echo "Usage: $0 -n <NAMESPACE>"
  divider
  exit 1
}

while getopts "n:" opt; do
  case ${opt} in
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

ZEN_WATCHER_POD=$(oc get pod -n ${NAMESPACE} -o name | grep -iw zen-watcher)
if [ -z "${ZEN_WATCHER_POD}" ]; then
    echo -e "[ERROR] zen-watcher pod not found"
    exit 1
fi

PANIC_FOUND=$(oc logs $ZEN_WATCHER_POD -n ${NAMESPACE} | grep -i panic)
if [ ! -z "${PANIC_FOUND}" ]; then
    echo -e "Panic found going to restart the zen-watcher pod"

    echo -e "[INFO] Deleting the ${ZEN_WATCHER_POD}"

    if ! oc delete ${ZEN_WATCHER_POD} -n ${NAMESPACE}; then
        echo -e "[ERROR] Unable to delete the pod ${ZEN_WATCHER_POD}"
        exit 1
    fi 
fi
