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
#   -e : <DEMO> (string), Defaults to ''
#
#   With defaults values
#     ./configure-postgres-db.sh
#
#   With overridden values
#     ./configure-postgres-db.sh -n <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -e <DEMO>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -e <DEMO>"
  divider
  exit 1
}

POSTGRES_NAMESPACE="cp4i"
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
DEMO=""
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
MISSING_PARAMS="false"
INFO="\xE2\x84\xB9"

while getopts "n:u:d:p:e:" opt; do
  case ${opt} in
  n)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  u)
    DB_USER="$OPTARG"
    ;;
  d)
    DB_NAME="$OPTARG"
    ;;
  p)
    DB_PASS="$OPTARG"
    ;;
  e)
    DEMO="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${DB_PASS// /}" ]]; then
  echo -e "$CROSS [ERROR] Database password param for for postgres is empty. Please provide a value for '-p' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${POSTGRES_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Postgres namespace param is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DB_USER// /}" ]]; then
  echo -e "$CROSS [ERROR] Database user param for postgres is empty. Please provide a value for '-u' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DB_NAME// /}" ]]; then
  echo -e "$CROSS [ERROR] Database name for postgres is empty. Please provide a value for '-d' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEMO// /}" ]]; then
  echo -e "$CROSS [ERROR] Demo type parameter is empty. Please provide a value for '-e' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

echo -e "$INFO [INFO] Waiting for postgres to be ready in the '$POSTGRES_NAMESPACE' namespace\n"
oc wait -n $POSTGRES_NAMESPACE --for=condition=available deploymentconfig --timeout=20m postgresql

divider

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"

echo -e "$INFO [INFO] Postgres namespace passed: $POSTGRES_NAMESPACE"
echo -e "$INFO [INFO] Database user name: '$DB_USER'"
echo -e "$INFO [INFO] Database name: '$DB_NAME'"
echo -e "$INFO [INFO] Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo -e "$INFO [INFO] Postgres svc name: '$DB_SVC'"

divider

# Check if the database exists
if ! oc exec -n $POSTGRES_NAMESPACE -i $DB_POD \
  -- psql -d $DB_NAME -c '\l' >/dev/null 2>&1; then
  echo -e "$INFO [INFO] Creating Database '$DB_NAME' and User '$DB_USER'"
  oc exec -n $POSTGRES_NAMESPACE -i $DB_POD \
    -- psql <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD $(echo "'${DB_PASS}'");
GRANT CONNECT ON DATABASE $DB_NAME TO $DB_USER;
EOF
  if [ $? -ne 0 ]; then
    echo -e "$CROSS [ERROR] Failed to create and setup database"
    exit 1
  fi
else
  echo -e "$INFO [INFO] Database and user already exist, updating user password only\n"
  oc exec -n $POSTGRES_NAMESPACE -i $DB_POD \
    -- psql <<EOF
ALTER USER $DB_USER WITH PASSWORD $(echo "'${DB_PASS}'");
EOF
fi

divider

if [[ "$DEMO" == "ddd" ]]; then
  echo -e "$INFO [INFO] Creating the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER'\n"
  if ! oc exec -n $POSTGRES_NAMESPACE -it $DB_POD \
    -- psql -U $DB_USER -d $DB_NAME -c \
    '
    CREATE TABLE IF NOT EXISTS QUOTES (
      QuoteID SERIAL PRIMARY KEY NOT NULL,
      Name VARCHAR(100),
      EMail VARCHAR(100),
      Address VARCHAR(100),
      USState VARCHAR(100),
      LicensePlate VARCHAR(100),
      ACMECost INTEGER,
      ACMEDate DATE,
      BernieCost INTEGER,
      BernieDate DATE,
      ChrisCost INTEGER,
      ChrisDate DATE
    );'; then
    echo -e "\n$CROSS [ERROR] Failed to create the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER'"
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Created the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER'"
  fi
else
  echo -e "$INFO [INFO] Creating the table 'QUOTES' and in the database '$DB_NAME' with the username '$DB_USER'"
  if ! oc exec -n $POSTGRES_NAMESPACE -it $DB_POD \
    -- psql -U $DB_USER -d $DB_NAME -c \
    '
    CREATE TABLE IF NOT EXISTS QUOTES (
      QuoteID VARCHAR(100) PRIMARY KEY NOT NULL,
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
    );'; then
    echo -e "\n$CROSS [ERROR] Failed to create the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER'"
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Created the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER'"
  fi
fi
