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
#   -n : <POSTGRES_NAMESPACE> (string), Defaults to 'postgres'
#   -r : <REPLICATION_PASSWORD> (string), Enables a replication user named "replication" with the specified password
#
# USAGE:
#   ./release-psql.sh
#******************************************************************************

function usage {
  echo "Usage: $0 -n <POSTGRES_NAMESPACE> -r <REPLICATION_PASSWORD>"
  exit 1
}

POSTGRES_NAMESPACE="postgres"
REPLICATION_PASSWORD=""

while getopts "n:u:d:p:r:" opt; do
  case ${opt} in
    n ) POSTGRES_NAMESPACE="$OPTARG"
      ;;
    r ) REPLICATION_PASSWORD="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo "Installing PostgreSQL..."
cat << EOF > postgres.env
  MEMORY_LIMIT=2Gi
  NAMESPACE=openshift
  DATABASE_SERVICE_NAME=postgresql
  POSTGRESQL_USER=admin
  POSTGRESQL_DATABASE=sampledb
  VOLUME_CAPACITY=1Gi
  POSTGRESQL_VERSION=10
EOF
oc create namespace ${POSTGRES_NAMESPACE}
oc process -n openshift postgresql-persistent --param-file=postgres.env | oc apply -n ${POSTGRES_NAMESPACE} -f -

echo "INFO: Waiting for postgres to be ready in the ${POSTGRES_NAMESPACE} namespace"
oc wait -n ${POSTGRES_NAMESPACE} --for=condition=available --timeout=20m deploymentconfig/postgresql

DB_POD=$(oc get pod -n ${POSTGRES_NAMESPACE} -l name=postgresql -o jsonpath='{.items[].metadata.name}')
echo "INFO: Found DB pod as: ${DB_POD}"

echo "INFO: Changing DB parameters for Debezium support"
oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD \
  -- psql << EOF
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_wal_senders=1;
ALTER SYSTEM SET max_replication_slots=1;
EOF

echo "INFO: Restarting postgres to pick up the parameter changes"
oc rollout latest -n ${POSTGRES_NAMESPACE} dc/postgresql

echo "INFO: Waiting for postgres to restart"
sleep 30
oc wait -n ${POSTGRES_NAMESPACE} --for=condition=available --timeout=20m deploymentconfig/postgresql

DB_POD=$(oc get pod -n ${POSTGRES_NAMESPACE} -l name=postgresql -o jsonpath='{.items[].metadata.name}')
echo "INFO: Found new DB pod as: ${DB_POD}"

if [[ ! -z "${REPLICATION_PASSWORD// }" ]]; then
  echo "INFO: Creating replication user"
  oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD \
    -- psql << EOF
CREATE ROLE replication REPLICATION LOGIN PASSWORD `echo "'${REPLICATION_PASSWORD}'"`;
EOF
fi
