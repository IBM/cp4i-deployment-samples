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
#   -g : <POSTGRES_NAMESPACE> (string), Defaults to 'postgres'
#   -u : <DB_USER> (string), Defaults to 'cp4i'
#   -d : <DB_NAME> (string), Defaults to 'db_cp4i'
#   -p : <DB_PASS> (string), Defaults to ''
#   -a : <ACE_CONFIGURATION_NAME> (string), Defaults to 'ace-policyproject'
#
#   With defaults values
#     ./create-ace-config.sh
#
#   With overridden values
#     ./create-ace-config.sh -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -a <ACE_CONFIGURATION_NAME>

function usage {
  echo "Usage: $0 -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -a <ACE_CONFIGURATION_NAME>"
  exit 1
}

NAMESPACE="cp4i"
POSTGRES_NAMESPACE="postgres"
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
ACE_CONFIGURATION_NAME="ace-policyproject"

while getopts "n:g:u:d:p:a:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    g ) POSTGRES_NAMESPACE="$OPTARG"
      ;;
    u ) DB_USER="$OPTARG"
      ;;
    d ) DB_NAME="$OPTARG"
      ;;
    p ) DB_PASS="$OPTARG"
      ;;
    a ) ACE_CONFIGURATION_NAME="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

if [[ -z "${DB_PASS// }" || -z "${NAMESPACE// }" || -z "${DB_USER// }" || -z "${DB_NAME// }" || -z "${POSTGRES_NAMESPACE// }" || -z "${ACE_CONFIGURATION_NAME// }" ]]; then
  echo -e "$cross ERROR: Some mandatory parameters are empty"
  usage
fi

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

echo "INFO: Creating policyproject for ace in the '$NAMESPACE' namespace"

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"

echo "INFO: Database user: '$DB_USER'"
echo "INFO: Database name: '$DB_NAME'"
echo "INFO: Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo "INFO: Postgres svc name: '$DB_SVC'"

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

# setting up policyproject for namespace
echo "INFO: Setting up policyproject in the '$NAMESPACE' namespace"
CONFIG="\
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: $ACE_CONFIGURATION_NAME
  namespace: $NAMESPACE
spec:
  contents: "$ENCODED"
  type: policyproject
"
  echo "${CONFIG}" > ${CURRENT_DIR}/tmp/policy-project-config.yaml
  echo "INFO: Output -> policy-project-config.yaml"
  cat ${CURRENT_DIR}/tmp/policy-project-config.yaml
  oc apply -f ${CURRENT_DIR}/tmp/policy-project-config.yaml
