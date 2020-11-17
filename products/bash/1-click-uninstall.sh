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
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <NAMESPACE> (string), namespace for the 1-click un-installation. Defaults to "cp4i"
#
# USAGE:
#   With defaults values
#     ./1-click-uninstall.sh
#
#   Overriding the namespace and release-name
#     ./1-click-uninstall.sh -n <NAMESPACE>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE>"
  divider
  exit 1
}

NAMESPACE="cp4i"
CURRENT_DIR=$(dirname $0)
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
missingParams="false"

while getopts "n:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "$cross ERROR: 1-click uninstall namespace is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

divider
echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info 1-click uninstallation namespace: $NAMESPACE"
divider

# Deleting the platform navigator CR
echo "INFO: Deleting the platform navigator CR in the ${NAMESPACE} namespace"
oc delete PlatformNavigator -n ${NAMESPACE} ${NAMESPACE}-navigator

divider

# Deleting all ClusterServiceVersions
echo "INFO: Deleting all ClusterServiceVersions except 'operand-deployment-lifecycle-manager' in the ${NAMESPACE} namespace"
oc delete ClusterServiceVersion -n ${NAMESPACE} $(oc get -n ${NAMESPACE} ClusterServiceVersion | grep -v operand-deployment-lifecycle-manager | awk '{print $1}' | sed -n '1!p')

divider

# Deleting all Subscription
echo "INFO: Deleting all Subscriptions in the ${NAMESPACE} namespace"
oc delete Subscription -n ${NAMESPACE} --all

divider

# Deleting the operator group
echo "INFO: Deleting the operator group in the ${NAMESPACE} namespace"
oc delete OperatorGroup -n ${NAMESPACE} ${NAMESPACE}-og

divider

# Deleting the ibm-entitlement-key secret
echo "INFO: Deleting ibm-entitlement-key secret"
oc delete secret -n ${NAMESPACE} ibm-entitlement-key

divider

echo -e "$tick INFO: Uninstallation is completed successfully"
