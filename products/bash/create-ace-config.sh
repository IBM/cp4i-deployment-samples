#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -g : <POSTGRES_NAMESPACE> (string), Defaults to 'postgres'
#   -u : <DB_USER> (string), Defaults to 'cp4i'
#   -d : <DB_NAME> (string), Defaults to 'db_cp4i'
#   -p : <DB_PASS> (string), Defaults to ''
#   -a : <ACE_CONFIGURATION_NAME> (string), Defaults to 'ace-policyproject'
#   -d : <DEBUG>
#
#   With defaults values
#     ./create-ace-config.sh
#
#   With overridden values
#     ./create-ace-config.sh -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -a <ACE_CONFIGURATION_NAME>

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
NAMESPACE="cp4i"
DEBUG=false
POSTGRES_NAMESPACE="postgres"
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
ACE_CONFIGURATION_NAME="ace-policyproject"
TYPES=("serverconf" "keystore" "policyproject" "setdbparms")
FILES=("tmp/serverconf.yaml" "tmp/keystore.p12" "DefaultPolicies" "tmp/setdbparms")
CURRENT_DIR=$(dirname $0)
CONFIG_YAML=$CURRENT_DIR/tmp/configuration.yaml
API_USER=bruce
API_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 ; echo)
KEYSTORE_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 ; echo)

function usage {
  echo "Usage: $0 -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -a <ACE_CONFIGURATION_NAME>"
  exit 1
}

function buildConfigurationCR {
  local type=$1
  local name=$2
  local file=$3
  echo "apiVersion: appconnect.ibm.com/v1beta1" >> $CONFIG_YAML
  echo "kind: Configuration" >> $CONFIG_YAML
  echo "metadata:" >> $CONFIG_YAML
  echo "  name: $name" >> $CONFIG_YAML
  echo "  namespace: $NAMESPACE" >> $CONFIG_YAML
  echo "spec:" >> $CONFIG_YAML
  echo "  contents: $(base64 $file)" >> $CONFIG_YAML
  echo "  type: $type" >> $CONFIG_YAML
  echo "---" >> $CONFIG_YAML
}

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

NAMES=("ace-serverconf" "ace-keystore" "$ACE_CONFIGURATION_NAME" "ace-setdbparms")

if [[ -z "${DB_PASS// }" || -z "${NAMESPACE// }" || -z "${DB_USER// }" || -z "${DB_NAME// }" || -z "${POSTGRES_NAMESPACE// }" || -z "${ACE_CONFIGURATION_NAME// }" ]]; then
  echo -e "$cross ERROR: Some mandatory parameters are empty"
  usage
fi

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

# Clean up exisitng configuration
[[ -f $CONFIG_YAML ]] && rm $CONFIG_YAML

# Store ace api password in secret
cat << EOF | oc apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: ace-api-creds
  namespace: $NAMESPACE
stringData:
  user: $API_USER
  pass: $API_PASS
  auth: "$API_USER:$API_PASS"
type: Opaque
EOF

echo "[INFO]  Creating policyproject for ace in the '$NAMESPACE' namespace"

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"

echo "[INFO]  Database user: '$DB_USER'"
echo "[INFO]  Database name: '$DB_NAME'"
echo "[INFO]  Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo "[INFO]  Postgres svc name: '$DB_SVC'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "[INFO]  Creating directories for default policies"
mkdir -p $CURRENT_DIR/tmp
mkdir -p $CURRENT_DIR/DefaultPolicies

echo "[INFO]  Creating mq policy"
cat << EOF > $CURRENT_DIR/DefaultPolicies/MQEndpointPolicy.policyxml
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

echo "[INFO] Creating postgresql policy"
cat << EOF > $CURRENT_DIR/DefaultPolicies/PostgresqlPolicy.policyxml
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

echo "[INFO] Creating basic auth policy"
cat << EOF > $CURRENT_DIR/DefaultPolicies/BasicAuthPolicy.policyxml
<policies>
  <policy policyType="SecurityProfiles" policyName="BasicAuthPolicy">
    <authentication>Local</authentication>
    <authenticationConfig>basicAuthOverride</authenticationConfig>
  </policy>
</policies>
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "[INFO] Creating policy descriptor"
cat << EOF > $CURRENT_DIR/DefaultPolicies/policy.descriptor
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
  <references/>
</ns2:policyProjectDescriptor>
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "[INFO] Creating server conf"
cat << EOF > $CURRENT_DIR/tmp/server.conf.yaml
serverConfVersion: 1
forceServerHTTPS: true
forceServerHTTPSecurityProfile: '{DefaultPolicies}:BasicAuthPolicy'
ResourceManagers:
  HTTPSConnector:
    KeystoreFile: '/home/aceuser/keystores/ace-keystore'
    KeystoreType: 'PKCS12'
    KeystorePassword: 'brokerKeystore::password'
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "[INFO] Creating keystore"
CERTS_KEY_BUNDLE=$CURRENT_DIR/tmp/certs-key.pem
CERTS=$CURRENT_DIR/tmp/certs.pem
KEY=$CURRENT_DIR/tmp/key.pem
KEYSTORE=$CURRENT_DIR/tmp/keystore.p12
oc get secret -n openshift-config-managed router-certs -o json | jq -r '.data | .[]' | base64 --decode > $CERTS_KEY_BUNDLE
openssl crl2pkcs7 -nocrl -certfile $CERTS_KEY_BUNDLE | openssl pkcs7 -print_certs -out $CERTS
openssl pkey -in $CERTS_KEY_BUNDLE -out $KEY
openssl pkcs12 -export -out $KEYSTORE -inkey $KEY -in $CERTS -password pass:$KEYSTORE_PASS

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "[INFO]  Creating setdbparms.txt"
cat << EOF > $CURRENT_DIR/tmp/setdbparms.txt
local::basicAuthOverride $API_USER $API_PASS
brokerKeystore::password ignore $KEYSTORE_PASS
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Generate configuration yaml
echo "[INFO]  Generating configuration yaml"
for i in ${!NAMES[@]}; do
  file=$CURRENT_DIR/${FILES[$i]}
  if [[ -d $CURRENT_DIR/${FILES[$i]} ]]; then
    python -m zipfile -c ${file}.zip $file/
    file=${file}.zip
  fi
  buildConfigurationCR ${TYPES[$i]} ${NAMES[$i]} $file
done
echo -e "[DEBUG] config yaml:\n$(cat -n $CONFIG_YAML)"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Apply configuration yaml
echo "[INFO]  Applying configuration yaml"
oc apply -f $CONFIG_YAML
