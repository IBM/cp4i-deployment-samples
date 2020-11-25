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
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -r : <NAV_REPLICAS> (string), Defaults to '2'
#   -p : <POSTGRES_NAMESPACE> (string), Namespace where postgres is setup, Defaults to 'postgres'
#   -o : <OMIT_INITIAL_SETUP> (optional), Parameter to decide if initial setup is to be done or not, Defaults to false
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <NAMESPACE> -r <NAV_REPLICAS> -p <POSTGRES_NAMESPACE> -o

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <NAV_REPLICAS> -p <POSTGRES_NAMESPACE> [-o]"
  exit 1
}

NAMESPACE="cp4i"
NAV_REPLICAS="2"
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
INFO="\xE2\x84\xB9"
SUFFIX="ddd"
POSTGRES_NAMESPACE="postgres"
MISSING_PARAMS="false"

while getopts "n:op:r:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  o)
    OMIT_INITIAL_SETUP=true
    ;;
  p)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  r)
    NAV_REPLICAS="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for driveway dent deletion demo is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${POSTGRES_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for postgres for driveway dent deletion demo is empty. Please provide a value for '-p' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${NAV_REPLICAS// /}" ]]; then
  echo -e "$CROSS [ERROR] Number of replicas for the platform navigator for driveway dent deletion demo is empty. Please provide a value for '-r' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

CURRENT_DIR=$(dirname $0)
echo -e "$INFO [INFO] Current directory for the driveway dent deletion demo: '$CURRENT_DIR'"
echo -e "$INFO [INFO] Namespace for running driveway dent deletion prereqs: '$NAMESPACE'"
echo -e "$INFO [INFO] Namespace for postgres for the driveway dent deletion demo: '$POSTGRES_NAMESPACE'"
echo -e "$INFO [INFO] Omit initial setup for the driveway dent deletion demo: '$OMIT_INITIAL_SETUP'"
echo -e "$INFO [INFO] Suffix for the postgres for the driveway dent deletion demo: '$SUFFIX'"

divider

if [[ "$OMIT_INITIAL_SETUP" == "false" ]]; then
  echo -e "$INFO [INFO] Installing OCP pipelines..."
  if ! $CURRENT_DIR/../../products/bash/install-ocp-pipeline.sh; then
    echo -e "$CROSS [ERROR] Failed to install OCP pipelines\n"
    exit 1
  else
    echo -e "$TICK [SUCCESS] Successfully installed OCP pipelines"
  fi # install-ocp-pipeline.sh

  divider

  echo -e "$INFO [INFO] Configuring secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the ddd demo..."
  if ! $CURRENT_DIR/../../products/bash/configure-ocp-pipeline.sh -n $NAMESPACE; then
    echo -e "$CROSS [ERROR] Failed to create secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the ddd demo\n"
    exit 1
  else
    echo -e "$TICK [SUCCESS] Successfully configured secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the ddd demo"
  fi # configure-ocp-pipeline.sh

  divider
fi

echo -e "$INFO [INFO] Installing prerequisites for the driveway dent deletion demo in the '$NAMESPACE' namespace...\n"

#namespaces for the driveway dent deletion demo pipeline
export dev_namespace=$NAMESPACE
export test_namespace=$NAMESPACE-ddd-test

oc project $dev_namespace

echo -e "$INFO [INFO] Test Namespace='$test_namespace'"

#creating new namespace for test/prod and adding namespace to sa
oc create namespace $test_namespace
oc adm policy add-scc-to-group privileged system:serviceaccounts:$test_namespace

divider

echo -e "$INFO [INFO] Creating operator group and subscription in the namespace '$test_namespace'"

if ! $CURRENT_DIR/../../products/bash/deploy-og-sub.sh -n $test_namespace; then
  echo -e "$CROSS [ERROR] Failed to apply subscriptions and csv in the namespace '$test_namespace'"
  exit 1
fi # deploy-og-sub.sh

divider

echo -e "$INFO [INFO] Adding permission for '$dev_namespace' to write images to openshift local registry in the '$test_namespace'"
# enable dev namespace to push to test namespace
oc -n $test_namespace policy add-role-to-user registry-editor system:serviceaccount:$dev_namespace:image-bot

divider

declare -a image_projects=("$dev_namespace" "$test_namespace")

for image_project in "${image_projects[@]}"; do #for_outer
  echo -e "$INFO [INFO] Generating user, database name and password for the postgres database in the '$image_project' namespace"
  DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
  DB_USER=$(echo ${image_project}_${SUFFIX} | sed 's/-/_/g')
  DB_NAME="db_$DB_USER"
  DB_PASS=$(
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
    echo
  )
  PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

  echo -e "$INFO [INFO] Creating a secret for the database user '$DB_USER' in the database '$DB_NAME' with the password generated"
  # everything inside 'data' must be in the base64 encoded form
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $image_project
  name: postgres-credential
type: Opaque
stringData:
  username: $DB_USER
data:
  password: $PASSWORD_ENCODED
EOF

  echo -e "$INFO [INFO] Creating '$DB_NAME' database and '$DB_USER' user in the postgres instance in the $POSTGRES_NAMESPACE namespace\n"
  if ! $CURRENT_DIR/../../products/bash/configure-postgres-db.sh -n $POSTGRES_NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -e $SUFFIX; then
    echo -e "\n$CROSS [ERROR] Failed to configure postgres in the '$POSTGRES_NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME'\n"
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Successfully configured postgres in the '$POSTGRES_NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME'\n"
  fi # configure-postgres-db.sh

  divider

  echo -e "$INFO [INFO] Creating ace postgres configuration and policy in the namespace '$image_project' with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  if ! $CURRENT_DIR/../../products/bash/create-ace-config.sh -n $image_project -g $POSTGRES_NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -s $SUFFIX; then
    echo -e "\n$CROSS [ERROR] Failed to configure ace in the '$image_project' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Successfully configured ace in the '$image_project' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  fi # create-ace-config.sh

  divider
done #for_outer_done

echo -e "$INFO [INFO] Creating secret to pull images from the ER in the '$test_namespace' namespace\n"

ER_REGISTRY=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths' | jq -r 'keys[]' | tr -d '"')
ER_USERNAME=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".username')
ER_PASSWORD=$(oc get secret -n $dev_namespace ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".password')

if ! oc get secrets -n $test_namespace ibm-entitlement-key; then
  oc create -n $test_namespace secret docker-registry ibm-entitlement-key --docker-server=$ER_REGISTRY \
    --docker-username=$ER_USERNAME --docker-password=$ER_PASSWORD -o yaml | oc apply -f -
  if [ $? -ne 0 ]; then
    echo -e "\n$CROSS [ERROR] Failed to create ibm-entitlement-key in test namespace ($test_namespace)"
    exit 1
  fi
else
  echo -e "\n$INFO [INFO] ibm-entitlement-key secret already exists in the '$test_namespace' namespace"
fi

divider

echo -e "$INFO [INFO] Releasing Navigator in the namespace '$test_namespace'"

if ! $CURRENT_DIR/../../products/bash/release-navigator.sh -n $test_namespace -r $NAV_REPLICAS; then
  echo -e "$CROSS [ERROR] Failed to release the platform navigator in the namespace '$test_namespace'"
  exit 1
fi # release-navigator.sh

divider

echo -e "$INFO [INFO] Releasing ACE dashboard in the namespace '$test_namespace'"

if ! $CURRENT_DIR/../../products/bash/release-ace-dashboard.sh -n $test_namespace; then
  echo -e "$CROSS [ERROR] Failed to release the ace dashboard in the namespace '$test_namespace'"
  exit 1
fi # release-ace-dashboard.sh

divider
echo -e "$TICK $ALL_DONE [SUCCESS] All prerequisites for the driveway dent deletion demo have been applied successfully $ALL_DONE $TICK"
divider
