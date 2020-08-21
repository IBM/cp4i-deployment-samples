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
# USAGE:
#   ./release-psql.sh
#******************************************************************************

echo "Installing PostgreSQL..."

cat << EOF > postgres.env
  MEMORY_LIMIT=2Gi
  NAMESPACE=openshift
  DATABASE_SERVICE_NAME=postgresql
  POSTGRESQL_USER=admin
  POSTGRESQL_PASSWORD=password
  POSTGRESQL_DATABASE=sampledb
  VOLUME_CAPACITY=1Gi
  POSTGRESQL_VERSION=9.6
EOF

oc create configmap postgres-config --from-file=postgres.env
oc process -n openshift postgresql-persistent --param-file=postgres.env > postgres.yaml
oc create namespace postgres
oc project postgres
oc apply -f postgres.yaml
oc create configmap -n postgres postgres-config --from-file=postgres.env
