#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#   - If running without parameters, all parameters must be set as environment variables
#
# PARAMETERS:
#   -a : <eventEnabledInsuranceDemo> (string), If event enabled insurance demo is to be setup. Defaults to "false"
#   -b : <demoDeploymentBranch> (string), The demo deployment branch to be used, Defaults to 'main'
#   -d : <demoPreparation> (string), If all demos are to be setup. Defaults to "false"
#   -e : <demoAPICEmailAddress> (string), The email address APIC uses to notify of portal configuration. Defaults to "your@email.address"
#   -f : <drivewayDentDeletionDemo> (string),  If driveway dent deletion demo is to be setup. Defaults to "false"
#   -h : <demoAPICMailServerHost> (string), Host name of the mail server. Defaults to "smtp.mailtrap.io"
#   -j : <tempERKey> (string), IAM API key for accessing the entitled registry.
#   -k : <tempRepo> (string), For accessing different Registry
#   -l : <DOCKER_REGISTRY_USER> (string), Docker registry username
#   -m : <demoAPICMailServerUsername> (string), Username for the mail server. Defaults to "<your-username>"
#   -n : <JOB_NAMESPACE> (string), Namespace for the 1-click install
#   -o : <demoAPICMailServerPort> (string), Port number of the mail server. Defaults to "2525"
#   -p : <csDefaultAdminPassword> (string), Common service default admin password
#   -q : <demoAPICMailServerPassword> (string), Password for the mail server.
#   -r : <navReplicaCount> (string), Platform navigator replicas, Defaults to 3
#   -s : <DOCKER_REGISTRY_PASS> (string), Docker registry password
#   -t : <ENVIRONMENT> (string), Environment for installation, 'staging' when you want to use the staging entitled registry
#   -u : <csDefaultAdminUser> (string), Default common service username. Defaults to "admin"
#   -v : <useFastStorageClass> (string), If using fast storage class for installation. Defaults to 'false'
#   -w : <testDrivewayDentDeletionDemoE2E> (string), If testing the Driveway dent deletion demo E2E. Defaults to 'false'
#
# USAGE:
#   With defaults values
#     ./1-click-install.sh
#
#   Overriding the params
#     ./1-click-install.sh -a <eventEnabledInsuranceDemo> -b <demoDeploymentBranch> -d <demoPreparation> -e <demoAPICEmailAddress> -f <drivewayDentDeletionDemo> -h <demoAPICMailServerHost> -j <tempERKey> -k <tempRepo> -l <DOCKER_REGISTRY_USER> -m <demoAPICMailServerUsername> -n <JOB_NAMESPACE> -o <demoAPICMailServerPort> -p <csDefaultAdminPassword> -q <demoAPICMailServerPassword> -r <navReplicaCount> -s <DOCKER_REGISTRY_PASS> -t <ENVIRONMENT> -u <csDefaultAdminUser> -v <useFastStorageClass>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -a <eventEnabledInsuranceDemo> -b <demoDeploymentBranch> -d <demoPreparation> -e <demoAPICEmailAddress> -f <drivewayDentDeletionDemo> -h <demoAPICMailServerHost> -j <tempERKey> -k <tempRepo> -l <DOCKER_REGISTRY_USER> -m <demoAPICMailServerUsername> -n <JOB_NAMESPACE> -o <demoAPICMailServerPort> -p <csDefaultAdminPassword> -q <demoAPICMailServerPassword> -r <navReplicaCount> -s <DOCKER_REGISTRY_PASS> -t <ENVIRONMENT> -u <csDefaultAdminUser> -v <useFastStorageClass>"
  divider
  exit 1
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
CURRENT_DIR=$(dirname $0)
missingParams="false"
IMAGE_REPO="cp.icr.io"
pwdChange="true"

while getopts "a:b:d:e:f:h:j:k:l:m:n:o:p:q:r:s:t:u:v:w:" opt; do
  case ${opt} in
  a)
    eventEnabledInsuranceDemo="$OPTARG"
    ;;
  b)
    demoDeploymentBranch="$OPTARG"
    ;;
  d)
    demoPreparation="$OPTARG"
    ;;
  e)
    demoAPICEmailAddress="$OPTARG"
    ;;
  f)
    drivewayDentDeletionDemo="$OPTARG"
    ;;
  h)
    demoAPICMailServerHost="$OPTARG"
    ;;
  j)
    tempERKey="$OPTARG"
    ;;
  k)
    tempRepo="$OPTARG"
    ;;
  l)
    DOCKER_REGISTRY_USER="$OPTARG"
    ;;
  m)
    demoAPICMailServerUsername="$OPTARG"
    ;;
  n)
    JOB_NAMESPACE="$OPTARG"
    ;;
  o)
    demoAPICMailServerPort="$OPTARG"
    ;;
  p)
    csDefaultAdminPassword="$OPTARG"
    ;;
  q)
    demoAPICMailServerPassword="$OPTARG"
    ;;
  r)
    navReplicaCount="$OPTARG"
    ;;
  s)
    DOCKER_REGISTRY_PASS="$OPTARG"
    ;;
  t)
    ENVIRONMENT="$OPTARG"
    ;;
  u)
    csDefaultAdminUser="$OPTARG"
    ;;
  v)
    useFastStorageClass="$OPTARG"
    ;;
  w)
    testDrivewayDentDeletionDemoE2E="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${JOB_NAMESPACE// /}" ]]; then
  echo -e "$cross ERROR: 1-click install namespace is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ -z "${navReplicaCount// /}" ]]; then
  echo -e "$cross ERROR: 1-click install platform navigator replica count is empty. Please provide a value for '-r' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminUser// /}" ]]; then
  echo -e "$cross ERROR: 1-click install default admin username is empty. Please provide a value for '-u' parameter."
  missingParams="true"
fi

if [[ -z "${demoPreparation// /}" ]]; then
  echo -e "$cross ERROR: 1-click install demo preparation parameter is empty. Please provide a value for '-d' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminPassword// /}" ]]; then
  echo -e "$cross ERROR: 1-click install default admin password is empty. Please provide a value for '-p' parameter."
  missingParams="true"
fi

if [[ -z "${ENVIRONMENT// /}" ]]; then
  echo -e "$cross ERROR: 1-click install environment is empty. Please provide a value for '-t' parameter."
  missingParams="true"
fi

if [[ -z "${demoDeploymentBranch// /}" ]]; then
  echo -e "$info INFO: 1-click install demo deployment branch is empty. Setting the default value of 'main' for it."
  demoDeploymentBranch="main"
fi

if [[ -z "${eventEnabledInsuranceDemo// /}" ]]; then
  echo -e "$info INFO: 1-click install event enabled insurance parameter is empty. Setting the default value of 'false' for it."
  eventEnabledInsuranceDemo="false"
fi

if [[ -z "${drivewayDentDeletionDemo// /}" ]]; then
  echo -e "$info INFO: 1-click install driveway dent deletion parameter is empty. Setting the default value of 'false' for it."
  drivewayDentDeletionDemo="false"
fi

if [[ -z "${useFastStorageClass// /}" ]]; then
  echo -e "$info INFO: 1-click install fast storage class flag is empty. Setting the default value of 'false' for it."
  useFastStorageClass="false"
fi

if [[ -z "${testDrivewayDentDeletionDemoE2E// /}" ]]; then
  echo -e "$info INFO: 1-click install test driveway dent deletion demo parameter is empty. Setting the default value of 'false' for it."
  testDrivewayDentDeletionDemoE2E="false"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  exit 1
fi

echo -e "$info Current directory: '$CURRENT_DIR'"
echo -e "$info 1-click namespace: '$JOB_NAMESPACE'"
echo -e "$info Navigator replica count: '$navReplicaCount'"
echo -e "$info Demo deployment branch: '$demoDeploymentBranch'"
echo -e "$info Default common service username: '$csDefaultAdminUser'"
echo -e "$info Setup all demos: '$demoPreparation'"
echo -e "$info Setup only event enabled insurance demo: '$eventEnabledInsuranceDemo'"
echo -e "$info Setup only driveway dent deletion demo: '$drivewayDentDeletionDemo'"
echo -e "$info APIC email address: '$demoAPICEmailAddress'"
echo -e "$info APIC mail server hostname: '$demoAPICMailServerHost'"
echo -e "$info APIC mail server port: '$demoAPICMailServerPort'"
echo -e "$info APIC mail server username: '$demoAPICMailServerUsername'"
echo -e "$info Image repository for downloading images: '$IMAGE_REPO'"
echo -e "$info Temporary ER repository: '$tempRepo'"
echo -e "$info Docker registry username: '$DOCKER_REGISTRY_USER'"
echo -e "$info Environment for installation: '$ENVIRONMENT'"
echo -e "$info If using fast storage for the installation: '$useFastStorageClass'"
echo -e "$info If testing the driveway dent deletion demo E2E: '$testDrivewayDentDeletionDemoE2E'"

divider

echo "INFO: Doing a validation check before installation..."
if ! $CURRENT_DIR/1-click-pre-validation.sh -n "$JOB_NAMESPACE" -p "$csDefaultAdminPassword" -r "$navReplicaCount" -u "$csDefaultAdminUser" -d "$demoPreparation"; then
  echo -e "$cross ERROR: Validation check failed"
  divider
  exit 1
fi

divider

if [[ -z "${tempERKey}" ]]; then
  # Use the entitlement key
  export DOCKER_REGISTRY_USER=${DOCKER_REGISTRY_USER:-ekey}
  export DOCKER_REGISTRY_PASS=${DOCKER_REGISTRY_PASS:-none}
else
  # Use the tempERKey override as an api key
  export DOCKER_REGISTRY_USER="iamapikey"
  export DOCKER_REGISTRY_PASS=${tempERKey}
fi

if [[ "$ENVIRONMENT" == "STAGING" ]]; then
  export IMAGE_REPO="cp.stg.icr.io"
fi

export IMAGE_REPO=${tempRepo:-$IMAGE_REPO}

if oc get namespace $JOB_NAMESPACE >/dev/null 2>&1; then
  echo -e "$info INFO: namespace $JOB_NAMESPACE already exists"
  divider
else
  echo "INFO: Creating $JOB_NAMESPACE namespace"
  if ! oc create namespace $JOB_NAMESPACE; then
    echo -e "$cross ERROR: Failed to create the $JOB_NAMESPACE namespace" 1>&2
    divider
    exit 1
  fi
fi

divider

# This storage class improves the pvc performance for small PVCs
echo "INFO: Creating new cp4i-block-performance storage class"
cat <<EOF | oc apply -n $JOB_NAMESPACE -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: cp4i-block-performance
 labels:
   kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-block
parameters:
 billingType: "hourly"
 classVersion: "2"
 sizeIOPSRange: |-
   "[1-39]Gi:[1000]"
   "[40-79]Gi:[2000]"
   "[80-99]Gi:[4000]"
   "[100-499]Gi:[5000-6000]"
   "[500-999]Gi:[5000-10000]"
   "[1000-1999]Gi:[10000-20000]"
   "[2000-2999]Gi:[20000-40000]"
   "[3000-12000]Gi:[24000-48000]"
 type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

if [[ "${useFastStorageClass}" == "true" ]]; then
  defaultStorageClass=$(oc get sc -o json | jq -r '.items[].metadata | select(.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .name')
  echo -e "$info INFO: Current default storage class is: $defaultStorageClass"

  echo -e "$info INFO: Making $defaultStorageClass non-default"
  oc patch storageclass $defaultStorageClass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

  echo -e "$info INFO: Making cp4i-block-performance default"
  oc patch storageclass cp4i-block-performance -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

divider

echo -e "$info INFO: Current storage classes:"
oc get sc

divider

# Create secret to pull images from the ER
echo "INFO: Creating secret to pull images from the ER"
oc -n ${JOB_NAMESPACE} create secret docker-registry ibm-entitlement-key \
--docker-server=${IMAGE_REPO} \
--docker-username=${DOCKER_REGISTRY_USER} \
--docker-password=${DOCKER_REGISTRY_PASS} \
--dry-run -o yaml | oc apply -f -

divider

echo "INFO: Checking for the platform-auth-idp-credentials secret"
if oc get secrets platform-auth-idp-credentials -n ibm-common-services; then
  pwdChange=false
  echo -e "$info INFO: Secret platform-auth-idp-credentials already exist so not updating password and username in the installation with provided values"
else
  echo -e "$info INFO: Secret platform-auth-idp-credentials does exist so will update password and username in the installation with provided values"
fi

divider

echo "INFO: Applying catalogsources"
cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m

---

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: docker.io/ibmcom/ibm-operator-catalog
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

divider

if ! $CURRENT_DIR/deploy-og-sub.sh -n ${JOB_NAMESPACE}; then
  echo -e "$cross ERROR: Failed to deploy the operator group and subscriptions" 1>&2
  divider
  exit 1
else
  echo -e "$tick INFO: Deployed the operator groups and subscriptions"
fi

divider

if ! oc get subscription -n ${JOB_NAMESPACE} ibm-integration-platform-navigator-v4.0-ibm-operator-catalog-openshift-marketplace -o json | jq -r .status.currentCSV; then
  echo -e "INFO:No ibm-integration-platform-navigator-v4.0-ibm-operator-catalog-openshift-marketplace present in ${JOB_NAMESPACE}"
  if ! oc get PlatformNavigator -n ${JOB_NAMESPACE}; then
    echo -e "INFO: No Operand PlatformNavigator in ${JOB_NAMESPACE}"
    if ! $CURRENT_DIR/release-navigator.sh -n ${JOB_NAMESPACE} -r ${navReplicaCount}; then
      echo -e "$cross ERROR: Failed to release navigator" 1>&2
      divider
      exit 1
    else
      echo -e "$tick INFO: Successfully released the platform navigator"
    fi
  else
    echo -e "$tick INFO: Platform Navigator already installed in ${JOB_NAMESPACE}"
  fi
fi

divider

# Only update common services username and password if common services is not already installed
if [ "${pwdChange}" == "true" ]; then
  if ! $CURRENT_DIR/change-cs-credentials.sh -u ${csDefaultAdminUser} -p ${csDefaultAdminPassword}; then
    echo -e "$cross ERROR: Failed to update the common services admin username/password" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully updated the common services admin username/password"
  fi
else
  echo -e "$info INFO: Retrieve the common service username using the command 'oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode' "
  echo -e "$info INFO: Retrieve the common service password using the command 'oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode' "
fi

divider

# ----------------------------------------------- Postgres for ddd and eei ------------------------------------------------------------

if [[ "${demoPreparation}" == "true" || "${eventEnabledInsuranceDemo}" == "true" || "${drivewayDentDeletionDemo}" == "true" ]]; then
  if ! $CURRENT_DIR/release-psql.sh -n "$JOB_NAMESPACE"; then
    echo -e "$cross ERROR: Failed to release PostgreSQL" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released PostgresSQL"
    divider
  fi
fi #postgres

# -------------------------------------------------- All other demos ----------------------------------------------------------------

if [[ "${demoPreparation}" == "true" ]]; then

  if ! $CURRENT_DIR/release-ar.sh -r ar-demo -n ${JOB_NAMESPACE}; then
    echo -e "$cross ERROR: Failed to release asset repo" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released asset repo"
  fi

  divider

  if ! $CURRENT_DIR/release-ace.sh -n ${JOB_NAMESPACE}; then
    echo -e "$cross : Failed to release ace dashboard and ace designer" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released ace dashboard and ace designer"
  fi

  divider

  if ! $CURRENT_DIR/release-mq.sh -n ${JOB_NAMESPACE} -t; then
    echo -e "$cross : Failed to release MQ" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released MQ"
    divider
  fi
fi #demoPreparation

# ------------------------------------------- Event Enabled Insurance demo specific ---------------------------------------------------

if [[ "${eventEnabledInsuranceDemo}" == "true" || "${demoPreparation}" == "true" ]]; then
  if ! $CURRENT_DIR/release-tracing.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to release tracing" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released tracing"
    divider
  fi

  if ! $CURRENT_DIR/release-es.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to release event streams" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released event streams"
    divider
  fi

  if ! $CURRENT_DIR/release-ace-dashboard.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to release ace dashboard" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released ace dashboard"
    divider
  fi

  if ! $CURRENT_DIR/release-apic.sh -n ${JOB_NAMESPACE} -t; then
    echo "ERROR: Failed to release apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released apic"
    divider
  fi

  if ! $CURRENT_DIR/register-tracing.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to register tracing. Tracing secret not created" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully registered tracing"
    divider
  fi

  export PORG_ADMIN_EMAIL=${demoAPICEmailAddress}
  export MAIL_SERVER_HOST=${demoAPICMailServerHost}
  export MAIL_SERVER_PORT=${demoAPICMailServerPort}
  export MAIL_SERVER_USERNAME=${demoAPICMailServerUsername}
  export MAIL_SERVER_PASSWORD=${demoAPICMailServerPassword}

  if ! $CURRENT_DIR/configure-apic-v10.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to configure apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully configured apic"
    divider
  fi

  # call prereqs for event enabled without branch and repo params
  # branch defaults to 'main' inside the prereqs
  # repo defaults to 'https://github.com/IBM/cp4i-deployment-samples.git' inside the prereqs
  if ! $CURRENT_DIR/../../EventEnabledInsurance/prereqs.sh -n ${JOB_NAMESPACE} -e ${JOB_NAMESPACE} -p ${JOB_NAMESPACE} -b ${demoDeploymentBranch}; then
    echo "ERROR: Failed to run event enabled insurance prereqs script" 1>&2
    divider
    exit 1
  fi
fi #eventEnabledInsuranceDemo

# ------------------------------------------- Driveway Dent Deletion demo specific ---------------------------------------------------

if [[ "${drivewayDentDeletionDemo}" == "true" || "${demoPreparation}" == "true" ]]; then

  divider

  if ! $CURRENT_DIR/../../DrivewayDentDeletion/Operators/prereqs.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to run driveway dent deletion prereqs script" 1>&2
    divider
    exit 1
  fi

  divider

  if ! $CURRENT_DIR/release-tracing.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to release tracing" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released tracing"
    divider
  fi

  if ! $CURRENT_DIR/release-ace-dashboard.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to release ace dashboard" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released ace dashboard"
    divider
  fi

  if ! $CURRENT_DIR/release-apic.sh -n ${JOB_NAMESPACE} -t; then
    echo "ERROR: Failed to release apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released apic"
    divider
  fi

  if ! $CURRENT_DIR/register-tracing.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to register tracing. Tracing secret not created" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully registered tracing"
    divider
  fi

  export PORG_ADMIN_EMAIL=${demoAPICEmailAddress}
  export MAIL_SERVER_HOST=${demoAPICMailServerHost}
  export MAIL_SERVER_PORT=${demoAPICMailServerPort}
  export MAIL_SERVER_USERNAME=${demoAPICMailServerUsername}
  export MAIL_SERVER_PASSWORD=${demoAPICMailServerPassword}

  if ! $CURRENT_DIR/configure-apic-v10.sh -n ${JOB_NAMESPACE}; then
    echo "ERROR: Failed to configure apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully configured apic"
    divider
  fi
fi #drivewayDentDeletionDemo

# -------------------------------------------------- All other demos ----------------------------------------------------------------

if [[ "${demoPreparation}" == "true" ]]; then
  export CP_USERNAME=${csDefaultAdminUser}
  export CP_PASSWORD=${csDefaultAdminPassword}
  export CP_CONSOLE=$(oc get routes -n ibm-common-services cp-console -o jsonpath='{.spec.host}')
  if [ -z "$CP_CONSOLE" ]; then
    echo "ERROR: Failed to get cp-console host" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully got cp-console host"
  fi

  divider

  export CP_CONSOLE_URL="https://${CP_CONSOLE}"
  if ! $CURRENT_DIR/ar_remote_create.sh -r ar-demo -n ${JOB_NAMESPACE} -o; then
    echo "ERROR: Failed to create remote for Asset repo" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully created remote for Asset repo"
  fi
fi #demoPreparation

divider

if [[ ("${demoPreparation}" == "true" || "${drivewayDentDeletionDemo}" == "true") && ("${testDrivewayDentDeletionDemoE2E}" == "true") ]]; then
  if ! $CURRENT_DIR/../../DrivewayDentDeletion/Operators/test-ddd.sh -n ${JOB_NAMESPACE} -b $demoDeploymentBranch; then
    echo "ERROR: Failed to run automated test for driveway dent deletion demo" 1>&2
    divider
    exit 1
  fi
fi
divider
