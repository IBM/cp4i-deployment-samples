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
#   -n : <POSTGRES_NAMESPACE> (string), Defaults to 'postgres'
#   -d : <DB_NAME> (string), Defaults to 'db_cp4i'
#   -u : <DB_USER> (string), Defaults to 'cp4i'
#   -p : <DB_PASS> (string), Defaults to ''
#
#   With defaults values
#     ./create-postgres-db.sh
#
#   With overridden values
#     ./create-postgres-db.sh -n <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS>

function usage {
  echo "Usage: $0 -n <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS>"
  exit 1
}

POSTGRES_NAMESPACE="postgres"
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"

while getopts "n:u:d:p:" opt; do
  case ${opt} in
    n ) POSTGRES_NAMESPACE="$OPTARG"
      ;;
    u ) DB_USER="$OPTARG"
      ;;
    d ) DB_NAME="$OPTARG"
      ;;
    p ) DB_PASS="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

if [[ -z "${DB_PASS// }" || -z "${POSTGRES_NAMESPACE// }" || -z "${DB_USER// }" || -z "${DB_NAME// }" ]]; then
  echo -e "$cross ERROR: Some mandatory parameters are empty"
  usage
fi

echo "INFO: Waiting for postgres to be ready in the '$POSTGRES_NAMESPACE' namespace"
oc wait -n $POSTGRES_NAMESPACE --for=condition=available deploymentconfig --timeout=20m postgresql

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.${POSTGRES_NAMESPACE}.svc.cluster.local"

echo "INFO: Postgres namespace passed: $POSTGRES_NAMESPACE"
echo "INFO: Database user name: '$DB_USER'"
echo "INFO: Database name: '$DB_NAME'"
echo "INFO: Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo "INFO: Postgres svc name: '$DB_SVC'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Check if the database exists
if ! oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD \
  -- psql -d $DB_NAME -c '\l' > /dev/null 2>&1 ; then
  echo "INFO: Creating Database '$DB_NAME' and User '$DB_USER'"
  oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD \
    -- psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD `echo "'${DB_PASS}'"`;
GRANT CONNECT ON DATABASE $DB_NAME TO $DB_USER;
EOF
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create and setup database"
    exit 1
  fi
else
  echo "INFO: Database and user already exist, updating user password only"
  oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD \
    -- psql << EOF
ALTER USER $DB_USER WITH PASSWORD `echo "'${DB_PASS}'"`;
EOF
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
