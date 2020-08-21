#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -r : <nav_replicas> (string), Defaults to '2'
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <namespace> -r <nav_replicas>

function usage {
  echo "Usage: $0 -n <namespace> -r <nav_replicas>"
  exit 1
}

namespace="cp4i"
nav_replicas="2"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
suffix="ddd"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) nav_replicas="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$suffix'"


echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Installing common prerequisites in the namespace '$namespace' for the ddd demo...\n"
if ! ${CURRENT_DIR}/../../products/bash/common-prereqs.sh -n ${namespace}; then
  printf "$cross "
  echo "ERROR: Failed to install common-prereqs in the namespace '$namespace' for the ddd demo"
  exit 1
else
  printf "$tick "
  echo "INFO: Successfuly installed common-prereqs in the namespace '$namespace' for the ddd demo"
fi  #${CURRENT_DIR}/../../products/bash/common-prereqs.sh -n ${namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

#namespaces for the driveway dent deletion demo pipeline
export dev_namespace=${namespace}
export test_namespace=${namespace}-ddd-test

oc project ${dev_namespace}

echo "INFO: Test Namespace='${test_namespace}'"

#creating new namespace for test/prod and adding namespace to sa
oc create namespace ${test_namespace}
oc adm policy add-scc-to-group privileged system:serviceaccounts:${test_namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Adding permission for '$dev_namespace' to write images to openshift local registry in the '$test_namespace'"
# enable dev namespace to push to test namespace
oc -n ${test_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

declare -a image_projects=("${dev_namespace}" "${test_namespace}")

for image_project in "${image_projects[@]}" #for_outer
do
  echo -e "\nINFO: Configuring postgres in the namespace '$image_project' with the suffix '$suffix'\n"
  if ! ${CURRENT_DIR}/../../products/bash/configure-postgres.sh -n ${image_project} -s $suffix; then
    echo -e "\n$cross ERROR: Failed to configure postgres in the namespace '$image_project' with the suffix '$suffix'"
    exit 1
  else
    echo -e "\n$tick INFO: Successfuly configured postgres in the namespace '$image_project' with the suffix '$suffix'"
  fi  #${CURRENT_DIR}/../../products/bash/configure-postgres.sh -n ${image_project} -s $suffix

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
  echo -e "INFO: Creating ace integration server configuration resources in the namespace '$image_project'"

  if ! ${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -s $suffix; then
    echo -e "\n$cross ERROR: Failed to configure ace in the namespace '$image_project'  with the suffix '$suffix'"
    exit 1
  else
    echo -e "\n$tick INFO: Successfuly configured ace in the namespace '$image_project' with the suffix '$suffix'"
  fi  #${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -s $suffix
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
done #for_outer_done

echo -e "INFO: Creating secret to pull images from the ER in the '${test_namespace}' namespace\n"

if ! oc get secrets -n ${test_namespace} ibm-entitlement-key; then
  oc create -n ${test_namespace} secret docker-registry ibm-entitlement-key --docker-server=${ER_REGISTRY} \
    --docker-username=${ER_USERNAME} --docker-password=${ER_PASSWORD} -o yaml | oc apply -f -
else
  echo -e "\nINFO: ibm-entitlement-key secret already exists in the '${test_namespace}' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating operator group and subscription in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/deploy-og-sub.sh -n ${test_namespace} ; then
  echo "ERROR: Failed to apply subscriptions and csv in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing Navigator in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-navigator.sh -n ${test_namespace} -r ${nav_replicas} ; then
  echo "ERROR: Failed to release the platform navigator in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing ACE dashboard in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-ace-dashboard.sh -n ${test_namespace} ; then
  echo "ERROR: Failed to release the ace dashboard in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the driveway dent deletion have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

