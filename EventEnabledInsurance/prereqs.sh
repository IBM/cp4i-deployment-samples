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
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <namespace>

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
SUFFIX="eei"
POSTGRES_NAMESPACE="postgres"

while getopts "n:r:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Creating secret in the '$namespace' namespace to pull images ER for pipelines in the eei demo...\n"
if ! ${CURRENT_DIR}/../products/bash/entitled-registry.sh -n ${namespace}; then
  printf "$cross "
  echo "ERROR: Failed to set up images from the entitled registry in the namespace '$namespace' for the eei demo"
  exit 1
else
  echo -e "$tick INFO: Successfuly set up images from the entitled registry in the namespace '$namespace' for the eei demo"
fi #${CURRENT_DIR}/../products/bash/entitled-registry.sh -n ${namespace}

echo "INFO: Installing OCP pipelines..."
if ! ${CURRENT_DIR}/../products/bash/create-ocp-pipeline.sh; then
  printf "$cross "
  echo -e "ERROR: Failed to install OCP pipelines\n"
  exit 1
else
  echo -e "$tick INFO: Successfuly installed OCP pipelines\n"
fi  #${CURRENT_DIR}/../products/bash/create-ocp-pipeline

echo "INFO: Configuring secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo..."
if ! ${CURRENT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}; then
  printf "$cross "
  echo -e "$cross ERROR: Failed to secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo\n"
  exit 1
else
  echo -e "$tick INFO: Successfuly configured secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo"
fi  #${CURRENT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Setting up the prerequisites for the event enabled insurance demo in the '$namespace' namespace...\n"
echo "INFO: Generating user, database name and password for the postgres database in the '$namespace' namespace"
DB_USER=$(echo ${namespace}_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Configuring postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'\n"
if ! ${CURRENT_DIR}/../products/bash/configure-postgres.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS; then
  echo -e "\n$cross ERROR: Failed to configure postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' amd suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$tick INFO: Successfuly configured postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #${CURRENT_DIR}/../products/bash/configure-postgres.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Creating ace postgres configuration and policy in the namespace '$namespace' with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  if ! ${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS; then
    echo -e "\n$cross ERROR: Failed to configure ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
    exit 1
  else
    echo -e "\n$tick INFO: Successfuly configured ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  fi  #${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the event enabled insurance demo have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
