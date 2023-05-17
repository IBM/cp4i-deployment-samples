#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -b <BLOCK_STORAGE_CLASS> -f <FILE_STORAGE_CLASS> -e <DDD_ENV> -u <BASE_URL> [-t]"
  divider
  exit 1
}

set -e

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../../products/bash/utils.sh

NAMESPACE="cp4i"
BLOCK_STORAGE_CLASS="cp4i-block-performance"
FILE_STORAGE_CLASS="cp4i-file-performance-gid"
DDD_ENV="dev"

while getopts "b:f:n:e:u" opt; do
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
  e)
    DDD_ENV="$OPTARG"
    ;;
  u)
    BASE_URL="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

IA_NAME=ddd-${DDD_ENV}
QM_NAME=mq-ddd-qm-${DDD_ENV}
CONFIGURATIONS="[keystore-ddd, policyproject-ddd-${DDD_ENV}, serverconf-ddd, setdbparms-ddd, application-ddd-${DDD_ENV}, barauth-empty]"
API_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-api/DrivewayDemo.bar'"]'
ACME_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-acme/AcmeV1.bar'"]'
BERNIE_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-bernie/BernieV1.bar'"]'
CHRIS_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-chris/CrumpledV1.bar'"]'

YAML=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: qm-${QM_NAME}-queues
data:
  myqm.mqsc: |
    DEFINE QLOCAL('AccidentIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('AccidentOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('BumperIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('BumperOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('CrumpledIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('CrumpledOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('AccidentIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('AccidentOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=${NAMESPACE}.${IA_NAME},OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationAssembly
metadata:
  name: ${IA_NAME}
spec:
  version: next
  license:
    accept: true
    license: L-RJON-CJR2RX
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
        license:
          license: L-YBXJ-ADJNSM
          accept: true
          use: NonProduction
        web:
          enabled: true
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
        name: ${IA_NAME}-ace-api
      spec:
        logFormat: basic
        barURL: ${API_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IA_NAME}-ace-acme
      spec:
        logFormat: basic
        barURL: ${ACME_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IA_NAME}-ace-bernie
      spec:
        logFormat: basic
        barURL: ${BERNIE_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IA_NAME}-ace-chris
      spec:
        logFormat: basic
        barURL: ${CHRIS_FILE}
        configurations: ${CONFIGURATIONS}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qm-${QM_NAME}-client
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
OCApplyYAML "$NAMESPACE" "$YAML"
echo -e "\n$TICK [SUCCESS] Successfully applied the Integration Assembly yaml"
