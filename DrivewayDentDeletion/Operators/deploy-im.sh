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
DDD_DEMO_TYPE="dev"
BLOCK_STORAGE_CLASS="cp4i-block-performance"
FILE_STORAGE_CLASS="cp4i-file-performance-gid"

while getopts "b:f:n:e:u:t" opt; do
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
  t)
    DDD_DEMO_TYPE="test"
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

echo "in deploy-im.sh: BASE_URL=${BASE_URL}"

IM_NAME=ddd-${DDD_DEMO_TYPE}
QM_NAME=mq-ddd-qm-${DDD_DEMO_TYPE}
CONFIGURATIONS="[keystore-ddd, policyproject-ddd-${DDD_ENV}, serverconf-ddd, setdbparms-ddd, application-ddd-${DDD_ENV}, barauth-empty]"
API_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-api/DrivewayDemo.bar'"]'
ACME_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-acme/AcmeV1.bar'"]'
BERNIE_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-bernie/BernieV1.bar'"]'
CHRIS_FILE='["'${BASE_URL}/DrivewayDentDeletion/Bar_files/ace-chris/CrumpledV1.bar'"]'

YAML=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: qm-${QM_NAME}-default
  labels:
    app.kubernetes.io/component: ibm-mq
    app.kubernetes.io/instance: ${NAMESPACE}.${IM_NAME}
    app.kubernetes.io/managed-by: ibm-integration-platform-navigator-operator
    app.kubernetes.io/name: integration-assembly
    app.kubernetes.io/part-of: ${NAMESPACE}.${IM_NAME}
data:
  myqm.ini: "Service:\n\tName=AuthorizationService\n\tEntryPoints=14\n\tSecurityPolicy=UserExternal"
  myqm.mqsc: |-
    DEFINE CHANNEL('MTLS.SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER') REPLACE
    ALTER QMGR CONNAUTH(' ')
    REFRESH SECURITY
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=*') USERSRC(NOACCESS) ACTION(REPLACE)
    SET CHLAUTH('*') TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(NOACCESS) ACTION(REPLACE)
---
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
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=${NAMESPACE}.${IM_NAME},OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ia-${NAMESPACE}-${IM_NAME}-ca
  labels:
    app.kubernetes.io/component: ibm-mq
    app.kubernetes.io/instance: ${NAMESPACE}.${IM_NAME}
    app.kubernetes.io/managed-by: ibm-integration-platform-navigator-operator
    app.kubernetes.io/name: integration-assembly
    app.kubernetes.io/part-of: ${NAMESPACE}.${IM_NAME}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ia-${NAMESPACE}-${IM_NAME}-ca
  labels:
    app.kubernetes.io/component: ibm-mq
    app.kubernetes.io/instance: ${NAMESPACE}.${IM_NAME}
    app.kubernetes.io/managed-by: ibm-integration-platform-navigator-operator
    app.kubernetes.io/name: integration-assembly
    app.kubernetes.io/part-of: ${NAMESPACE}.${IM_NAME}
spec:
  commonName: ca
  isCA: true
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ia-${NAMESPACE}-${IM_NAME}-ca
  secretName: ia-${NAMESPACE}-${IM_NAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: qm-${QM_NAME}-issuer
  labels:
    app.kubernetes.io/component: ibm-mq
    app.kubernetes.io/instance: ${NAMESPACE}.${IM_NAME}
    app.kubernetes.io/managed-by: ibm-integration-platform-navigator-operator
    app.kubernetes.io/name: integration-assembly
    app.kubernetes.io/part-of: ${NAMESPACE}.${IM_NAME}
spec:
  ca:
    secretName: ia-${NAMESPACE}-${IM_NAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qm-${QM_NAME}-server
  labels:
    app.kubernetes.io/component: ibm-mq
    app.kubernetes.io/instance: ${NAMESPACE}.${IM_NAME}
    app.kubernetes.io/managed-by: ibm-integration-platform-navigator-operator
    app.kubernetes.io/name: integration-assembly
    app.kubernetes.io/part-of: ${NAMESPACE}.${IM_NAME}
spec:
  commonName: cert
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: qm-${QM_NAME}-issuer
  secretName: qm-${QM_NAME}-server
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationAssembly
metadata:
  name: ${IM_NAME}
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
        version: 9.3.1.0-r3
        web:
          enabled: true
        pki:
          keys:
          - name: default
            secret:
              items:
              - tls.key
              - tls.crt
              secretName: qm-${QM_NAME}-server
          trust:
          - name: rootca
            secret:
              items:
              - ca.crt
              secretName: qm-${QM_NAME}-server
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
        name: ${IM_NAME}-ace-api
      spec:
        logFormat: basic
        barURL: ${API_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IM_NAME}-ace-acme
      spec:
        logFormat: basic
        barURL: ${ACME_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IM_NAME}-ace-bernie
      spec:
        logFormat: basic
        barURL: ${BERNIE_FILE}
        configurations: ${CONFIGURATIONS}
    - kind: IntegrationRuntime
      metadata:
        name: ${IM_NAME}-ace-chris
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
  commonName: ${NAMESPACE}.${IM_NAME}
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
