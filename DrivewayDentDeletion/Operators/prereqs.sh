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
SUFFIX="ddd"
POSTGRES_NAMESPACE="postgres"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) nav_replicas="$OPTARG"
      ;;
    \? ) usage;
      ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"


echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Installing OCP pipelines..."
if ! ${CURRENT_DIR}/../../products/bash/install-ocp-pipeline.sh; then
  echo -e "$cross ERROR: Failed to install OCP pipelines\n"
  exit 1
else
  echo -e "$tick INFO: Successfully installed OCP pipelines"
fi  #${CURRENT_DIR}/../../products/bash/install-ocp-pipeline

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Configuring secrets and permissions related to ocp pipelines in the '$namespace' namespace for the ddd demo..."
if ! ${CURRENT_DIR}/../../products/bash/configure-ocp-pipeline.sh -n ${namespace}; then
  echo -e "$cross ERROR: Failed to create secrets and permissions related to ocp pipelines in the '$namespace' namespace for the ddd demo\n"
  exit 1
else
  echo -e "$tick INFO: Successfully configured secrets and permissions related to ocp pipelines in the '$namespace' namespace for the ddd demo"
fi  #${CURRENT_DIR}/../../products/bash/configure-ocp-pipeline.sh -n ${namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Installing prerequisites for the driveway dent deletion demo in the '$namespace' namespace...\n"

#namespaces for the driveway dent deletion demo pipeline
export dev_namespace=${namespace}
export test_namespace=${namespace}-ddd-test

oc project ${dev_namespace}

echo "INFO: Test Namespace='${test_namespace}'"

#creating new namespace for test/prod and adding namespace to sa
oc create namespace ${test_namespace}
oc adm policy add-scc-to-group privileged system:serviceaccounts:${test_namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating operator group and subscription in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/deploy-og-sub.sh -n ${test_namespace} ; then
  echo -e "$cross ERROR: Failed to apply subscriptions and csv in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Adding permission for '$dev_namespace' to write images to openshift local registry in the '$test_namespace'"
# enable dev namespace to push to test namespace
oc -n ${test_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

declare -a image_projects=("${dev_namespace}" "${test_namespace}")

for image_project in "${image_projects[@]}" #for_outer
do
  echo "INFO: Generating user, database name and password for the postgres database in the '$image_project' namespace"
  DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
  DB_USER=$(echo ${image_project}_${SUFFIX} | sed 's/-/_/g')
  DB_NAME="db_$DB_USER"
  DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
  PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

  echo "INFO: Creating a secret for the database user '$DB_USER' in the database '$DB_NAME' with the password generated"
  # everything inside 'data' must be in the base64 encoded form
  cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $image_project
  name: postgres-credential
type: Opaque
stringData:
  username: $DB_USER
data:
  password: ${PASSWORD_ENCODED}
EOF

  echo -e "INFO: Creating '$DB_NAME' database and '$DB_USER' user in the postgres instance in the ${POSTGRES_NAMESPACE} namespace\n"
  if ! ${CURRENT_DIR}/../../products/bash/configure-postgres-db.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS -e $SUFFIX; then
    echo -e "\n$cross ERROR: Failed to configure postgres in the '$POSTGRES_NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME'\n"
    exit 1
  else
    echo -e "\n$tick INFO: Successfully configured postgres in the '$POSTGRES_NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME'\n"
  fi  #configure-postgres-db.sh

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo -e "INFO: Creating ace postgres configuration and policy in the namespace '$image_project' with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  if ! ${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -g $POSTGRES_NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -s $SUFFIX; then
    echo -e "\n$cross ERROR: Failed to configure ace in the '$image_project' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
    exit 1
  else
    echo -e "\n$tick INFO: Successfully configured ace in the '$image_project' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  fi  #${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -g $POSTGRES_NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -s $SUFFIX

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
done #for_outer_done

echo -e "INFO: Creating secret to pull images from the ER in the '${test_namespace}' namespace\n"

ER_REGISTRY=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths' | jq -r 'keys[]' | tr -d '"')
ER_USERNAME=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".username')
ER_PASSWORD=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".password')

if ! oc get secrets -n ${test_namespace} ibm-entitlement-key; then
  oc create -n ${test_namespace} secret docker-registry ibm-entitlement-key --docker-server=${ER_REGISTRY} \
    --docker-username=${ER_USERNAME} --docker-password=${ER_PASSWORD} -o yaml | oc apply -f -
  if [ $? -ne 0 ]; then
    echo -e "\n$cross ERROR: Failed to create ibm-entitlement-key in test namespace ($test_namespace)"
    exit 1
  fi
else
  echo -e "\nINFO: ibm-entitlement-key secret already exists in the '${test_namespace}' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing Navigator in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-navigator.sh -n ${test_namespace} -r ${nav_replicas} ; then
  echo -e "$cross ERROR: Failed to release the platform navigator in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing ACE dashboard in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-ace-dashboard.sh -n ${test_namespace} ; then
  echo -e $cross "ERROR: Failed to release the ace dashboard in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the driveway dent deletion demo have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
