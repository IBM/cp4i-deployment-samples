#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function usage {
  echo "Usage: $0 -n <namespace>"
}

NAMESPACE="cp4i"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

DB_POD=$(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_USER=$(echo $NAMESPACE | sed 's/-/_/g')
DB_NAME=db_${DB_USER}
DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)

cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: ${NAMESPACE}
  name: postgres-credential
type: Opaque
data:
  username: ${NAMESPACE}
  password: $(echo $DB_PASS | base64)
EOF

# Check if the database exists
if ! oc exec -n postgres -it ${DB_POD} \
  -- psql -U ${DB_USER} -d ${DB_NAME} -c '\l' ; then
  echo "INFO: Creating Database ${DB_NAME} , User ${DB_USER}, "
  oc exec -n postgres -it ${DB_POD} \
    -- psql << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD 'password';
GRANT CONNECT ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create and setup database" 1>&2
    exit 1
  fi
else
  echo "INFO: Database already exists, skipping this step"
fi

echo "INFO: Create QUOTES table in the database ${DB_NAME}"
if ! oc exec -n postgres -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -c \
  'CREATE TABLE IF NOT EXISTS QUOTES (
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
    ChrisDate DATE);'; then
  echo "ERROR: Failed to create QUOTES table" 1>&2
  exit 1
fi
