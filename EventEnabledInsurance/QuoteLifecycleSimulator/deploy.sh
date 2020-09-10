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
#   -t : <TICK_MILLIS> (string), Defaults to '1000'
#   -m : <MOBILE_TEST_ROWS> (string), Defaults to '10'
#
#   With defaults values
#     ./deploy-simulator.sh
#
#   With overridden values
#     ./deploy-simulator.sh -n <namespace>

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
PG_PORT=5432
TICK_MILLIS=1000
MOBILE_TEST_ROWS=10

while getopts "n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"

if [[ -z "${namespace// }" ]]; then
  echo -e "$cross ERROR: A mandatory parameter 'namespace' is empty"
  usage
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"
PG_HOST=$DB_SVC
echo "INFO: Postgres service name for the simulator application: '$PG_HOST'"

PG_USER=$(echo ${namespace}_sor_${SUFFIX} | sed 's/-/_/g')
PG_DATABASE="db_$PG_USER"
echo "INFO: The database for the simulator app to connect to the postgres: $PG_DATABASE"
echo "INFO: The username for the simulator app to connect to the postgres: $PG_USER"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating a deployment for the lifecycle simulator application..."
cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: $namespace
  name: quote-simulator-$SUFFIX
  labels:
    app: quote-simulator-$SUFFIX
    demo: eei
spec:
  selector:
    matchLabels:
      app: quote-simulator-$SUFFIX
  replicas: 0
  template:
    metadata:
      labels:
        app: quote-simulator-$SUFFIX
        demo: eei
    spec:
      containers:
        - name: quote-simulator-$SUFFIX
          image: image-registry.openshift-image-registry.svc:5000/$namespace/quote-simulator-$SUFFIX
          env:
          - name: PG_HOST
            value: "$PG_HOST"
          - name: PG_USER
            value: "$PG_USER"
          - name: PG_DATABASE
            value: "$PG_DATABASE"
          - name: PG_PORT
            value: "$PG_PORT"
          - name: TICK_MILLIS
            value: "$TICK_MILLIS"
          - name: MOBILE_TEST_ROWS
            value: "$MOBILE_TEST_ROWS"
          - name: PG_PASSWORD
            valueFrom:
              secretKeyRef:
                key: password
                name: postgres-credential-eei
EOF
