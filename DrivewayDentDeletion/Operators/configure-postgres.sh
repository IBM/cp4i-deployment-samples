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
#   -s : <SUFFIX> (string), Defaults to ''
#
#   With defaults values
#     ./configure-postgres.sh
#
#   With overridden values
#     ./configure-postgres.sh -n <NAMESPACE> -s <SUFFIX>

function usage {
  echo "Usage: $0 -n <NAMESPACE> -s <SUFFIX>"
  exit 1
}

NAMESPACE="cp4i"
SUFFIX=""

while getopts "n:s:p:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    s ) SUFFIX="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

DB_POD=$(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="$(oc get cm -n postgres postgres-config -o json | jq '.data["postgres.env"] | split("\n  ")' | grep DATABASE_SERVICE_NAME | cut -d "=" -f 2- | tr -dc '[a-z0-9-]\n').postgres.svc.cluster.local"
DB_USER=$(echo ${NAMESPACE}_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
DB_PASSFILE="$DB_SVC:5432:$DB_NAME:$DB_USER:${DB_PASS}"

PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

# everything inside data must be in the base64 encoded form
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $NAMESPACE
  name: postgres-credential
type: Opaque
stringData:
  username: $DB_USER
data:
  password: ${PASSWORD_ENCODED}
EOF

# Script to generate a .pgpass file so we don't have to authenticate every psql cmd
# remove existing user and associated password in .pgpass file
cat << EOF > pgpass_gen.sh
#!/bin/bash
if [ -f /var/lib/pgsql/.pgpass ]; then
  sed -i '/$DB_NAME:$DB_USER/d' /var/lib/pgsql/.pgpass
  echo "${DB_PASSFILE}" >> /var/lib/pgsql/.pgpass
else
  cat << EEOOFF > /var/lib/pgsql/.pgpass
${DB_PASSFILE}
EEOOFF
  chmod 600 /var/lib/pgsql/.pgpass
fi

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create a script to generate a .pgpass file in the '$NAMESPACE' namespace"
  exit 1
fi
EOF

#copying the script to the postgres container and execute it
chmod +x pgpass_gen.sh

# If rsync complains of error(s) similar to the following, ignore it:
#
# rsync: failed to set permissions on "/var/lib/pgsql/.": Operation not permitted
# rsync error: some files could not be transferred (code 23)
# error: exit status 23
#
oc rsync -n postgres . $DB_POD:/var/lib/pgsql --exclude="*" --include="pgpass_gen.sh"
oc exec -n postgres -it $DB_POD -- /var/lib/pgsql/pgpass_gen.sh

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure database password in the '$NAMESPACE' namespace"
  exit 1
fi

# Check if the database exists
if ! oc exec -n postgres -it $DB_POD \
  -- psql -d $DB_NAME -c '\l' ; then
  echo "INFO: Creating Database '$DB_NAME' and User '$DB_USER'"
  oc exec -n postgres -it $DB_POD \
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
  oc exec -n postgres -it $DB_POD \
    -- psql << EOF
ALTER USER $DB_USER WITH PASSWORD `echo "'${DB_PASS}'"`;
EOF
fi

echo "INFO: Create QUOTES table in the database '$DB_NAME' with the username '$DB_USER'"
if ! oc exec -n postgres -it $DB_POD \
    -- psql -U $DB_USER -d $DB_NAME -h $DB_SVC -c \
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
  echo "ERROR: Failed to create QUOTES table in the namesapce '$NAMESPACE'"
  exit 1
fi
