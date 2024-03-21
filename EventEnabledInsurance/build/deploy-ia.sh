#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

echo "Start of EEI deploy-ia.sh"

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -b <BLOCK_STORAGE_CLASS> -f <FILE_STORAGE_CLASS> -u <BASE_URL> - a <ACE_REST_FILE> -d <DB_WRITER_FILE> -c <CONFIGURATIONS>"
  divider
  exit 1
}

set -e

echo "About to source utils.sh"
CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../../products/bash/utils.sh

NAMESPACE="cp4i"
BLOCK_STORAGE_CLASS="ocs-storagecluster-ceph-rbd"
FILE_STORAGE_CLASS="ocs-storagecluster-cephfs"

echo "About to process options"

while getopts "b:f:n:u:c:" opt; do
  case ${opt} in
  b)
    BLOCK_STORAGE_CLASS="$OPTARG"
    ;;
  f)
    FILE_STORAGE_CLASS="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  u)
    BASE_URL="$OPTARG"
    ;;
  c)
    CONFIGURATIONS="$OPTARG"
    ;;

  \?)
    usage
    ;;
  esac
done

echo "About to set env vars"

IA_NAME=eei
QM_NAME=mq-eei-qm
ACE_REST_FILE='["'${BASE_URL}/EventEnabledInsurance/ACE/BarFiles/REST.bar'"]'
DB_WRITER_FILE='["'${BASE_URL}/EventEnabledInsurance/ACE/BarFiles/DB-WRITER.bar'"]'

PROVIDER_ORG="main-demo"
CATALOG="${PROVIDER_ORG}-catalog"
PLATFORM_API="https://$(oc get route -n ${NAMESPACE} ademo-mgmt-platform-api -o jsonpath="{.spec.host}")/"
CERTIFICATE="$(oc get route -n ${NAMESPACE} ademo-mgmt-platform-api -o json | jq -r .spec.tls.caCertificate)"
CERTIFICATE_NEWLINES_REPLACED=$(echo "${CERTIFICATE}" | awk '{printf "%s\\n", $0}')


echo "About to get name/uid from operator-info configmap"

set +e
json=$(oc get configmap -n $NAMESPACE operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | $JQ -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | $JQ -r '.data.METADATA_UID')
fi
set -e

echo "About to create YAML"

YAML=$(cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: apim-credentials
$(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
  - apiVersion: integration.ibm.com/v1beta1
    kind: Demo
    name: ${METADATA_NAME}
    uid: ${METADATA_UID}"
fi)
type: Opaque
stringData:
  base_url: "${PLATFORM_API}"
  username: cp4i-admin
  password: engageibmAPI1
  trusted_cert: "${CERTIFICATE_NEWLINES_REPLACED}"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: qm-${QM_NAME}-queues
$(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
  - apiVersion: integration.ibm.com/v1beta1
    kind: Demo
    name: ${METADATA_NAME}
    uid: ${METADATA_UID}"
fi)
data:
  myqm.mqsc: |
    DEFINE QLOCAL('QuoteBO') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('Quote') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('QuoteBO') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('Quote') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=${NAMESPACE}.${IA_NAME},OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationAssembly
metadata:
  name: ${IA_NAME}
  annotations:
    "operator.ibm.com/ia-managed-integrations-dry-run": "false"
$(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
  - apiVersion: integration.ibm.com/v1beta1
    kind: Demo
    name: ${METADATA_NAME}
    uid: ${METADATA_UID}"
fi)
spec:
  version: 2023.2.1
  license:
    accept: true
    license: L-YBXJ-ADJNSM
    use: CloudPakForIntegrationNonProduction
  storage:
    readWriteOnce:
      class: ${BLOCK_STORAGE_CLASS}
    readWriteMany:
      class: ${FILE_STORAGE_CLASS}
  managedInstances:
    list:
    - kind: QueueManager
      metadata:
        name: ${QM_NAME}
      spec:
        queueManager:
          mqsc:
            - configMap:
                name: qm-${QM_NAME}-default
                items:
                  - myqm.mqsc
            - configMap:
                name: qm-${QM_NAME}-queues
                items:
                  - myqm.mqsc
  managedIntegrations:
    list:
    - kind: IntegrationRuntime
      metadata:
        name: eei-ace-rest
      spec:
        barURL: ${ACE_REST_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: eei-db-writer
      spec:
        barURL: ${DB_WRITER_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: Product
      metadata:
        name: eei-product
      spec:
        state: Published
        definition:
          product: 1.0.0
          info:
            title: ${NAMESPACE}-product-eei
            name: ${NAMESPACE}-product-eei
            version: '1.0'
          gateways:
            - datapower-api-gateway
          plans:
            default-plan:
              rate-limits:
                default:
                  value: 100/1hour
              title: Default Plan
              description: Default Plan
              approval: false
        apis:
          integrationRuntimes:
            - name: eei-ace-rest
        share:
          apim:
            credentialsSecret: apim-credentials
            providerOrg: ${PROVIDER_ORG}
            catalog: ${CATALOG}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qm-${QM_NAME}-client
$(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
  echo "ownerReferences:
  - apiVersion: integration.ibm.com/v1beta1
    kind: Demo
    name: ${METADATA_NAME}
    uid: ${METADATA_UID}"
fi)
spec:
  commonName: ${NAMESPACE}.${IA_NAME}
  subject:
    organizationalUnits:
    - my-team
  secretName: qm-${QM_NAME}-client
  issuerRef:
    name: qm-${QM_NAME}-issuer
    kind: Issuer
    group: cert-manager.io
EOF
)

echo "Applying YAML"
OCApplyYAML "$NAMESPACE" "$YAML"
echo -e "\n$TICK [SUCCESS] Successfully applied the Integration Assembly yaml"
