#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#****

# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -s : <SUFFIX> (string), Defaults to ''
#
#   With defaults values
#     ./create-ace-config.sh
#
#   With overridden values
#     ./create-ace-config.sh -n <NAMESPACE> -s <SUFFIX>

function usage {
  echo "Usage: $0 -n <NAMESPACE> -s <SUFFIX>"
}

NAMESPACE="cp4i"

while getopts "n:s:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    s ) SUFFIX="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

echo "INFO: Creating policyproject for ace in the '$NAMESPACE' namespace"

# Add suffix created for a user and database for the policy
DB_USER=$(echo ${NAMESPACE}_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_SVC="$(oc get cm -n postgres postgres-config -o json | jq '.data["postgres.env"] | split("\n  ")' | grep DATABASE_SERVICE_NAME | cut -d "=" -f 2- | tr -dc '[a-z0-9-]\n').postgres.svc.cluster.local"
DB_PASS=$(oc get secret -n $NAMESPACE postgres-credential --template={{.data.password}} | base64 --decode)

echo "INFO: Postgres db is: '$DB_NAME'"
echo "INFO: Postgres user is: '$DB_USER'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating directories for default policies"
mkdir -p ${CURRENT_DIR}/tmp
mkdir -p ${CURRENT_DIR}/DefaultPolicies

echo "INFO: Creating default.policyxml"
cat << EOF > ${CURRENT_DIR}/DefaultPolicies/default.policyxml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="MQEndpoint" policyName="MQEndpointPolicy" policyTemplate="MQEndpoint">
    <connection>CLIENT</connection>
    <destinationQueueManagerName>QUICKSTART</destinationQueueManagerName>
    <queueManagerHostname>mq-ddd-qm-ibm-mq</queueManagerHostname>
    <listenerPortNumber>1414</listenerPortNumber>
    <channelName>ACE_SVRCONN</channelName>
    <securityIdentity></securityIdentity>
    <useSSL>false</useSSL>
    <SSLPeerName></SSLPeerName>
    <SSLCipherSpec></SSLCipherSpec>
  </policy>
</policies>
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating PostgresqlPolicy.policyxml"
cat << EOF > ${CURRENT_DIR}/DefaultPolicies/PostgresqlPolicy.policyxml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="JDBCProviders" policyName="PostgresqlPolicy" policyTemplate="DB2_91">
    <databaseName>${DB_NAME}</databaseName>
    <databaseType>Postgresql</databaseType>
    <databaseVersion>999</databaseVersion>
    <type4DriverClassName>org.postgresql.Driver</type4DriverClassName>
    <type4DatasourceClassName>org.postgresql.xa.PGXADataSource</type4DatasourceClassName>
    <connectionUrlFormat>jdbc:postgresql://[serverName]:[portNumber]/[databaseName]?user=${DB_USER}&amp;password=${DB_PASS}</connectionUrlFormat>
    <connectionUrlFormatAttr1></connectionUrlFormatAttr1>
    <connectionUrlFormatAttr2></connectionUrlFormatAttr2>
    <connectionUrlFormatAttr3></connectionUrlFormatAttr3>
    <connectionUrlFormatAttr4></connectionUrlFormatAttr4>
    <connectionUrlFormatAttr5></connectionUrlFormatAttr5>
    <serverName>${DB_SVC}</serverName>
    <portNumber>5432</portNumber>
    <jarsURL></jarsURL>
    <databaseSchemaNames>useProvidedSchemaNames</databaseSchemaNames>
    <description></description>
    <maxConnectionPoolSize>0</maxConnectionPoolSize>
    <securityIdentity></securityIdentity>
    <environmentParms></environmentParms>
    <jdbcProviderXASupport>false</jdbcProviderXASupport>
    <useDeployedJars>true</useDeployedJars>
  </policy>
</policies>
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating policy.descriptor"
cat << EOF > ${CURRENT_DIR}/DefaultPolicies/policy.descriptor
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
  <references/>
</ns2:policyProjectDescriptor>
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Listing the files in ${CURRENT_DIR}/DefaultPolicies"
ls ${CURRENT_DIR}/DefaultPolicies

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Create a zip for default policies
echo "INFO: Creating a zip for default policies"
python -m zipfile -c ${CURRENT_DIR}/policyproject.zip ${CURRENT_DIR}/DefaultPolicies

echo "INFO: Printing contents of '${CURRENT_DIR}':"
ls -lFA ${CURRENT_DIR}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: encoding the policy project in the '$NAMESPACE' namespace"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  ENCODED=$(base64 --wrap=0 ${CURRENT_DIR}/policyproject.zip)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  ENCODED=$(base64 ${CURRENT_DIR}/policyproject.zip)
else
  ENCODED=$(base64 --wrap=0 ${CURRENT_DIR}/policyproject.zip)
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# setting up policyporject for namespace
echo "INFO: Setting up policyporject in the '$NAMESPACE' namespace"
CONFIG="\
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ace-policyproject
  namespace: $NAMESPACE
spec:
  contents: "$ENCODED"
  type: policyproject
"
  echo "${CONFIG}" > ${CURRENT_DIR}/tmp/policy-project-config.yaml
  echo "INFO: Output -> policy-project-config.yaml"
  cat ${CURRENT_DIR}/tmp/policy-project-config.yaml
  oc apply -f ${CURRENT_DIR}/tmp/policy-project-config.yaml
