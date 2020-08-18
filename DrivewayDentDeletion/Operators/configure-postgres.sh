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
#
#   With defaults values
#     ./configure-postgres.sh
#
#   With overridden values
#     ./configure-postgres.sh -n <NAMESPACE>

function usage {
  echo "Usage: $0 -n <NAMESPACE>"
}

NAMESPACE="cp4i"

while getopts "n:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

DB_POD=$(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="$(oc get cm -n postgres postgres-config -o json | jq '.data["postgres.env"] | split("\n  ")' | grep DATABASE_SERVICE_NAME | cut -d "=" -f 2- | tr -dc '[a-z0-9-]\n').postgres.svc.cluster.local"
DB_USER=$(echo $NAMESPACE | sed 's/-/_/g')
DB_NAME=db_${DB_USER}
DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
DB_PASSFILE="${DB_SVC}:5432:${DB_NAME}:${DB_USER}:${DB_PASS}"

PASSWORD_ENCODED=$(echo -n $DB_PASS | base64)

# everything inside data must be in the base64 encoded form
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: ${NAMESPACE}
  name: postgres-credential
type: Opaque
stringData:
  username: ${DB_USER}
data:
  password: ${PASSWORD_ENCODED}
EOF

# Script to generate a .pgpass file so we don't have to authenticate every psql cmd
cat << EOF > script.sh
#!/bin/bash
if [ -f /var/lib/pgsql/.pgpass ]; then
  echo "${DB_PASSFILE}" >> /var/lib/pgsql/.pgpass
else
  cat << EEOOFF > /var/lib/pgsql/.pgpass
${DB_PASSFILE}
EEOOFF
  chmod 600 /var/lib/pgsql/.pgpass
fi

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create a script to generate a .pgpass file in the '$NAMESPACE' namespace" 1>&2
  exit 1
fi
EOF

#coopying the script to the postgres container and execute it 
chmod +x script.sh
oc rsync -n postgres . ${DB_POD}:/var/lib/pgsql --exclude="*" --include="script.sh"
oc exec -n postgres -it ${DB_POD} -- /var/lib/pgsql/script.sh

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure database password in the '$NAMESPACE' namespace" 1>&2
  exit 1
fi

# Check if the database exists
if ! oc exec -n postgres -it ${DB_POD} \
  -- psql -d ${DB_NAME} -c '\l' ; then
  echo "INFO: Creating Database ${DB_NAME} , User ${DB_USER}, "
  oc exec -n postgres -it ${DB_POD} \
    -- psql << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD `echo "'${DB_PASS}'"`;
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
    -- psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_SVC} -c \
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
