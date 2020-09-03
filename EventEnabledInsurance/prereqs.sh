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
ACE_CONFIGURATION_NAME="ace-policyproject-$SUFFIX"

while getopts "n:" opt; do
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

echo "INFO: Installing OCP pipelines..."
if ! ${CURRENT_DIR}/../products/bash/install-ocp-pipeline.sh; then
  echo -e "$cross ERROR: Failed to install OCP pipelines\n"
  exit 1
else
  echo -e "$tick INFO: Successfully installed OCP pipelines"
fi #${CURRENT_DIR}/../products/bash/install-ocp-pipeline

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Configuring secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo..."
if ! ${CURRENT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}; then
  echo -e "$cross ERROR: Failed to create secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo\n"
  exit 1
else
  echo -e "$tick INFO: Successfully configured secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo"
fi #${CURRENT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Setting up the prerequisites for the event enabled insurance demo in the '$namespace' namespace...\n"
echo "INFO: Generating user, database name and password for the postgres database in the '$namespace' namespace"
DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_USER=$(echo ${namespace}_sor_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_PASS=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  echo
)
PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

  echo "INFO: Creating a secret for the lifecycle simulator app to conenct to postgres"
  # everything inside 'data' must be in the base64 encoded form
  cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $namespace
  name: postgres-credential-$SUFFIX
type: Opaque
data:
  password: ${PASSWORD_ENCODED}
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Configuring postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'\n"
if ! ${CURRENT_DIR}/../products/bash/create-postgres-db.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS; then
  echo -e "\n$cross ERROR: Failed to configure postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' amd suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$tick INFO: Successfully configured postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #${CURRENT_DIR}/../products/bash/create-postgres-db.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS

echo -e "\nINFO: Creating the table 'QUOTES' and in the database '$DB_NAME' with the username '$DB_USER' in the '$namespace' namespace"
if ! oc exec -n $POSTGRES_NAMESPACE -it $DB_POD \
  -- psql -U $DB_USER -d $DB_NAME -c \
  "
  CREATE TABLE IF NOT EXISTS QUOTES (
    QuoteID SERIAL PRIMARY KEY NOT NULL,
    Source VARCHAR(20),
    Name VARCHAR(100),
    EMail VARCHAR(100),
    Age INTEGER,
    Address VARCHAR(100),
    USState VARCHAR(100),
    LicensePlate VARCHAR(100),
    DescriptionOfDamage VARCHAR(100),
    ClaimStatus INTEGER,
    ClaimCost INTEGER
  );
  "; then
  echo -e "\n$cross ERROR: Failed to create the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER' in the namespace '$namespace'"
  exit 1
else
  echo -e "\n$tick INFO: Created the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER' in the namespace '$namespace'"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

REPLICATION_USER=$(echo ${namespace}_sor_replication_${SUFFIX} | sed 's/-/_/g')
REPLICATION_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
REPLICATION_PASSWORD_ENCODED=$(echo -n ${REPLICATION_PASSWORD} | base64)

echo "INFO: Creating replication user"
oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD -- psql -d $DB_NAME << EOF
CREATE ROLE $REPLICATION_USER REPLICATION LOGIN PASSWORD `echo "'${REPLICATION_PASSWORD}'"`;
GRANT ALL PRIVILEGES ON TABLE quotes TO $REPLICATION_USER;
CREATE PUBLICATION db_eei_quotes FOR TABLE quotes;
EOF

echo "INFO: Creating secret for replication user"
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $namespace
  name: eei-postgres-replication-credential
type: Opaque
stringData:
  connector.properties: |-
    dbName: ${DB_NAME}
    dbUsername: ${REPLICATION_USER}
    dbPassword: ${REPLICATION_PASSWORD}
EOF

echo -e "INFO: Creating ace postgres configuration and policy in the namespace '$namespace' with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
if ! ${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS -a $ACE_CONFIGURATION_NAME; then
  echo -e "\n$cross ERROR: Failed to configure ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$tick INFO: Successfully configured ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS -a $ACE_CONFIGURATION_NAME

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the event enabled insurance demo have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
