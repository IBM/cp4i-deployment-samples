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
#   -b : <demoDeploymentBranch> (string), The demo deployment branch to be used, Defaults to 'main'
#   -c : <DEFAULT_FILE_STORAGE> (string), Defines the default file storage for the cluster. Defaults to "cp4i-file-performance-gid"
#   -g : <DEFAULT_BLOCK_STORAGE> (string), Defines the default block storage for the cluster. Defaults to "cp4i-block-performance"
#   -j : <tempERKey> (string), IAM API key for accessing the entitled registry.
#   -k : <tempRepo> (string), For accessing different Registry
#   -l : <DOCKER_REGISTRY_USER> (string), Docker registry username
#   -n : <JOB_NAMESPACE> (string), Namespace for the 1-click install
#   -r : <navReplicaCount> (string), Platform navigator replicas, Defaults to 3
#   -s : <DOCKER_REGISTRY_PASS> (string), Docker registry password
#   -t : <ENVIRONMENT> (string), Environment for installation, 'staging' when you want to use the staging entitled registry
#   -v : <useFastStorageClass> (string), If using fast storage class for installation. Defaults to 'true'
#   -x : <CLUSTER_TYPE> (string), Defines the cluster type for 1-click installation. Defaults to 'roks'
#   -y : <CLUSTER_SCOPED> (string) (optional), If the operator and platform navigator install should cluster scoped or not. Defaults to 'false'
#   -z : <HA_ENABLED> (string), if cluster in single-zone is highly available. Defaults to 'true'
#
# USAGE:
#   With defaults values
#     ./1-click-install.sh  -s <DOCKER_REGISTRY_PASS>
#
#   Overriding the params
#     ./1-click-install.sh -b <demoDeploymentBranch> -c <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE> -j <tempERKey> -k <tempRepo> -l <DOCKER_REGISTRY_USER> -n <JOB_NAMESPACE> -r <navReplicaCount> -s <DOCKER_REGISTRY_PASS> -t <ENVIRONMENT> -v <useFastStorageClass> -x <CLUSTER_TYPE> -y -z <HA_ENABLED>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -b <demoDeploymentBranch> -c <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE> -j <tempERKey> -k <tempRepo> -l <DOCKER_REGISTRY_USER> -n <JOB_NAMESPACE> -r <navReplicaCount> -s <DOCKER_REGISTRY_PASS> -t <ENVIRONMENT> -v <useFastStorageClass> -x <CLUSTER_TYPE> [-y]"
  divider
  exit 1
}

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
MISSING_PARAMS="false"
IMAGE_REPO="cp.icr.io"
PASSWORD_CHANGE="true"
DEFAULT_BLOCK_STORAGE="cp4i-block-performance"
DEFAULT_FILE_STORAGE="cp4i-file-performance-gid"
CLUSTER_TYPE="roks"
CLUSTER_SCOPED="false"
HA_ENABLED="true"

while getopts "b:c:g:j:k:l:n:r:s:t:v:x:z:y" opt; do
  case ${opt} in
  b)
    demoDeploymentBranch="$OPTARG"
    ;;
  c)
    DEFAULT_FILE_STORAGE="$OPTARG"
    ;;
  g)
    DEFAULT_BLOCK_STORAGE="$OPTARG"
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
  n)
    JOB_NAMESPACE="$OPTARG"
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
  v)
    useFastStorageClass="$OPTARG"
    ;;
  x)
    CLUSTER_TYPE="$OPTARG"
    ;;
  y)
    CLUSTER_SCOPED="true"
    ;;
  z)
    HA_ENABLED="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

# Set seconds to zero to calculate time taken for overall the 1-click experience
SECONDS=0

if [[ -z "${JOB_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] 1-click install namespace is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${navReplicaCount// /}" ]]; then
  echo -e "$CROSS [ERROR] 1-click install platform navigator replica count is empty. Please provide a value for '-r' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${ENVIRONMENT// /}" ]]; then
  echo -e "$CROSS [ERROR] 1-click install environment is empty. Please provide a value for '-t' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${demoDeploymentBranch// /}" ]]; then
  echo -e "$INFO [INFO] 1-click install demo deployment branch is empty. Setting the default value of 'main' for it."
  demoDeploymentBranch="main"
fi

if [[ -z "${useFastStorageClass// /}" ]]; then
  echo -e "$INFO [INFO] 1-click install fast storage class flag is empty (-v). Setting the default value of 'false' for it."
  useFastStorageClass="false"
fi

if [[ -z "${DOCKER_REGISTRY_PASS// /}" ]]; then
  echo -e "$INFO [INFO] 1-click docker registry password parameter is empty. Please provide a value for '-s' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_BLOCK_STORAGE// /}" && "$(echo "$CLUSTER_TYPE" | tr '[:upper:]' '[:lower:]')" != "roks" ]]; then
  echo -e "$INFO [INFO] 1-click default block storage parameter is empty. Please provide a value for '-g' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_FILE_STORAGE// /}" ]]; then
  echo -e "$INFO [INFO] 1-click default file storage parameter is empty. Please provide a value for '-c' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${CLUSTER_TYPE// /}" ]]; then
  echo -e "$INFO [INFO] 1-click cluster type parameter is empty. Please provide a value for '-x' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${HA_ENABLED// /}" ]]; then
  echo -e "$INFO [INFO] HA_ENABLED parameter is empty. Please provide a value for '-z' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  exit 1
fi

export CLUSTER_TYPE=$CLUSTER_TYPE
export CLUSTER_SCOPED=$CLUSTER_SCOPED

if [[ "$CLUSTER_SCOPED" == "true" ]]; then
  DEPLOY_OPERATOR_NAMESPACE="openshift-operators"
else
  DEPLOY_OPERATOR_NAMESPACE=$JOB_NAMESPACE
fi

divider && echo -e "$INFO [INFO] Current cluster type: '$CLUSTER_TYPE'"
echo -e "$INFO [INFO] Default file storage class: '$DEFAULT_FILE_STORAGE'"
echo -e "$INFO [INFO] Current directory for 1-click install: '$CURRENT_DIR'"
echo -e "$INFO [INFO] 1-click namespace: '$JOB_NAMESPACE'"
echo -e "$INFO [INFO] Cluster scoped operator install: '$CLUSTER_SCOPED'"
echo -e "$INFO [INFO] Namespace for setting up the operators: '$DEPLOY_OPERATOR_NAMESPACE'"
echo -e "$INFO [INFO] Navigator replica count: '$navReplicaCount'"
echo -e "$INFO [INFO] Demo deployment branch: '$demoDeploymentBranch'"
echo -e "$INFO [INFO] Image repository for downloading images: '$IMAGE_REPO'"
echo -e "$INFO [INFO] Temporary ER repository: '$tempRepo'"
echo -e "$INFO [INFO] Docker registry username: '$DOCKER_REGISTRY_USER'"
echo -e "$INFO [INFO] Environment for installation: '$ENVIRONMENT'"
echo -e "$INFO [INFO] If using fast storage for the installation: '$useFastStorageClass'"

divider


echo -e "$INFO [INFO] Doing a validation check before installation..."
if ! $CURRENT_DIR/1-click-pre-validation.sh -n "$JOB_NAMESPACE" -r "$navReplicaCount"; then
  echo -e "$CROSS [ERROR] 1-click pre validation failed"
  divider
  exit 1
fi

divider

if [[ -z "$tempERKey" ]]; then
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
  echo -e "$INFO [INFO] namespace $JOB_NAMESPACE already exists"
else
  echo -e "$INFO [INFO] Creating the '$JOB_NAMESPACE' namespace\n"
  if ! oc create namespace $JOB_NAMESPACE; then
    echo -e "$CROSS [ERROR] Failed to create the '$JOB_NAMESPACE' namespace"
    divider
    exit 1
  else
    echo -e "\n$TICK [SUCCESS] Successfully created the '$JOB_NAMESPACE' namespace"
  fi
fi

divider

if echo $CLUSTER_TYPE | grep -iqF roks; then
  if ! $CURRENT_DIR/create-roks-performance-scs.sh -d "$useFastStorageClass" ; then
    echo -e "$CROSS [ERROR] Failed to create the performance storage classes"
    exit 1
  fi

  defaultStorageClass=$(oc get sc -o json | jq -r '.items[].metadata | select(.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .name')
  DEFAULT_BLOCK_STORAGE=$defaultStorageClass

  if [[ "$useFastStorageClass" == "true" ]]; then
    DEFAULT_BLOCK_STORAGE="cp4i-block-performance"
    DEFAULT_FILE_STORAGE="cp4i-file-performance-gid"
  fi
  divider
fi

echo -e "$INFO [INFO] Default block storage class: '$DEFAULT_BLOCK_STORAGE'" && divider
echo -e "$INFO [INFO] Default file storage class: '$DEFAULT_FILE_STORAGE'" && divider
echo -e "$INFO [INFO] Current storage classes:\n"
oc get sc
divider

# Create/update secret to pull images from the ER
echo -e "$INFO [INFO] Creating secret to pull images from the ER\n"
EXISTING_DOCKER_AUTHS=$(oc get secret --namespace ${JOB_NAMESPACE} ibm-entitlement-key -o json 2>/dev/null | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r .auths)
if [[ "$EXISTING_DOCKER_AUTHS" == "" ]]; then
  EXISTING_DOCKER_AUTHS='{}'
fi
NEW_DOCKER_AUTHS=$(oc create secret docker-registry --namespace ${JOB_NAMESPACE} ibm-entitlement-key \
  --docker-server=${IMAGE_REPO} \
  --docker-username=${DOCKER_REGISTRY_USER} \
  --docker-password=${DOCKER_REGISTRY_PASS} \
  --dry-run=client -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r .auths)

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  BASE64_FLAG="-w0"
else
  BASE64_FLAG=""
fi
COMBINED_DOCKER_CFG_B64=$(echo $EXISTING_DOCKER_AUTHS $NEW_DOCKER_AUTHS | jq -s -r '{"auths": add}' | base64 $BASE64_FLAG)
YAML=$(cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ibm-entitlement-key
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $COMBINED_DOCKER_CFG_B64
EOF
)
OCApplyYAML "$JOB_NAMESPACE" "$YAML"

divider

echo -e "$INFO [INFO] Checking for the platform-auth-idp-credentials secret\n"
if oc get secrets platform-auth-idp-credentials -n ibm-common-services 2>/dev/null; then
  PASSWORD_CHANGE=false
  echo -e "\n$INFO [INFO] Secret platform-auth-idp-credentials already exist so not updating password and username in the installation with provided values"
else
  echo -e "\n$INFO [INFO] Secret platform-auth-idp-credentials does exist so will update password and username in the installation with provided values"
fi

divider

if ! $CURRENT_DIR/create-catalog-sources.sh; then
  echo -e "$CROSS [ERROR] Failed to create catalog sources"
  divider
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Created the catalog sources"
fi

divider

if ! $CURRENT_DIR/deploy-og-sub.sh -n "$DEPLOY_OPERATOR_NAMESPACE"; then
  echo -e "$CROSS [ERROR] Failed to deploy the operator group and subscriptions"

  echo 'Output of "oc get nodes" for info:'
  oc get nodes

  divider
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Deployed the operator groups and subscriptions"
fi

divider

echo "release-nav"

if ! $CURRENT_DIR/release-navigator.sh -n "$JOB_NAMESPACE" -r "$navReplicaCount" -s "$DEFAULT_FILE_STORAGE" ; then
  echo -e "$CROSS [ERROR] Failed to release navigator"
  divider
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Successfully released the platform navigator"
fi

divider

echo "release-assets"

if ! $CURRENT_DIR/release-assetrepo.sh -n "$JOB_NAMESPACE" -r "$navReplicaCount" -s "$DEFAULT_BLOCK_STORAGE" ; then
  echo -e "$CROSS [ERROR] Failed to release asset repo"
  divider
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Successfully released the platform asset repo"
fi

divider

divider && echo -e "$INFO [INFO] The 1-click installation took $(($SECONDS / 60 / 60 % 24)) hour(s) $(($SECONDS / 60 % 60)) minutes and $(($SECONDS % 60)) seconds." && divider
