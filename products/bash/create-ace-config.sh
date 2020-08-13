#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#****
function usage {
  echo "Usage: $0 -n <namespace>"
}

namespace="cp4i"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

namespace=$(echo $namespace | sed 's/-/_/g')

mkdir -p ${PWD}/tmp
mkdir -p ${PWD}/DefaultPolicies

echo "INFO: Creating policyproject for ace"
echo "************************************"
echo "INFO: Creating default.policyxml"
cat << EOF > ${PWD}/DefaultPolicies/default.policyxml
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

echo "INFO: Creating PostgresqlPolicy.policyxml"
cat << EOF > ${PWD}/DefaultPolicies/PostgresqlPolicy.policyxml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="JDBCProviders" policyName="PostgresqlPolicy" policyTemplate="DB2_91">
    <databaseName>db_${namespace}</databaseName>
    <databaseType>Postgresql</databaseType>
    <databaseVersion>999</databaseVersion>
    <type4DriverClassName>org.postgresql.Driver</type4DriverClassName>
    <type4DatasourceClassName>org.postgresql.xa.PGXADataSource</type4DatasourceClassName>
    <connectionUrlFormat>jdbc:postgresql://[serverName]:[portNumber]/[databaseName]?user=${namespace}&amp;password=password</connectionUrlFormat>
    <connectionUrlFormatAttr1></connectionUrlFormatAttr1>
    <connectionUrlFormatAttr2></connectionUrlFormatAttr2>
    <connectionUrlFormatAttr3></connectionUrlFormatAttr3>
    <connectionUrlFormatAttr4></connectionUrlFormatAttr4>
    <connectionUrlFormatAttr5></connectionUrlFormatAttr5>
    <serverName>postgresql.postgres.svc.cluster.local</serverName>
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

echo "INFO: Creating policy.descriptor"
cat << EOF > ${PWD}/DefaultPolicies/policy.descriptor
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
  <references/>
</ns2:policyProjectDescriptor>
EOF

echo "INFO: Listing the files in ${PWD}/DefaultPolicies"
ls ${PWD}/DefaultPolicies

mkdir -p ${PWD}/tmp/extracted
FILES=${PWD}/DefaultPolicies/*
for f in $FILES
do
  echo "********************* $f **************************"
  cat $f
done
python -m zipfile -c policyproject.zip ${PWD}/DefaultPolicies
python -m zipfile -e policyproject.zip ${PWD}/tmp/extracted
ls -lFA ${PWD}
ls -lFA ${PWD}/tmp/extracted
FILES=${PWD}/tmp/extracted/*
for f in $FILES
do
  echo "********************* Extracted: $f **************************"
  cat $f
done


echo "INFO: encoding the policy project"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  temp=$(base64 --wrap=0 ${PWD}/policyproject.zip)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  temp=$(base64 ${PWD}/DefaultPolicies/policyproject.zip)
else
  temp=$(base64 --wrap=0 ${PWD}/policyproject.zip)
fi

# setting up policyporject for both namespaces
declare -a image_projects=("${dev_namespace}" "${test_namespace}")
echo "Creating secrets to push images to openshift local registry"
for image_project in "${image_projects[@]}"
do
configyaml="\
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ace-policyproject
  namespace: ${image_project}
spec:
  contents: "$temp"
  type: policyproject
"
  echo "${configyaml}" > ${PWD}/tmp/policy-project-config.yaml
  echo "INFO: Output -> policy-project-config.yaml"
  cat ${PWD}/tmp/policy-project-config.yaml
  oc apply -f ${PWD}/tmp/policy-project-config.yaml
done