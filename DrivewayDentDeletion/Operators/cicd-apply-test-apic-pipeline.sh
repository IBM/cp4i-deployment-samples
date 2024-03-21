#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#****

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#   -f : <DEFAULT_FILE_STORAGE> (string), Default to 'cp4i-file-performance-gid'
#   -g : <DEFAULT_BLOCK_STORAGE> (string), Default to 'cp4i-block-performance'
#   -a : <HA_ENABLED>, default to 'true'
#
#   With defaults values
#     ./cicd-apply-apic-pipeline.sh
#
#   With overridden values
#     ./cicd-apply-apic-pipeline.sh -n <NAMESPACE> -r <REPO> -b <BRANCH> -f <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE> -a <HA_ENABLED>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <REPO> -b <BRANCH> -f <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE>"
  divider
  exit 1
}

# default vars
NAMESPACE="cp4i"
BRANCH="main"
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../../products/bash/utils.sh
MISSING_PARAMS="false"
DEFAULT_FILE_STORAGE="ocs-storagecluster-cephfs"
DEFAULT_BLOCK_STORAGE="ocs-storagecluster-ceph-rbd"
HA_ENABLED="true"

while getopts "n:r:b:f:g:a:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  r)
    REPO="$OPTARG"
    ;;
  b)
    BRANCH="$OPTARG"
    ;;
  f)
    DEFAULT_FILE_STORAGE="$OPTARG"
    ;;
  g)
    DEFAULT_BLOCK_STORAGE="$OPTARG"
    ;;
  a)
    HA_ENABLED="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for driveway dent deletion demo is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${REPO// /}" ]]; then
  echo -e "$CROSS [ERROR] Repository name parameter is empty. Please provide a value for '-r' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${BRANCH// /}" ]]; then
  echo -e "$CROSS [ERROR] Branch name parameter is empty. Please provide a value for '-b' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_FILE_STORAGE// /}" ]]; then
  echo -e "$CROSS [ERROR] File storage type is empty. Please provide a value for '-f' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_BLOCK_STORAGE// /}" ]]; then
  echo -e "$CROSS [ERROR] Block storage type is empty. Please provide a value for '-g' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${HA_ENABLED// /}" ]]; then
  echo -e "$CROSS [ERROR] HA_ENABLED parameter is empty. Please provide a value for '-a' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

echo -e "$INFO [INFO] Current directory: '$CURRENT_DIR'"
echo -e "$INFO [INFO] Namespace: '$NAMESPACE'"
echo -e "$INFO [INFO] Branch name: '$BRANCH'"
echo -e "$INFO [INFO] Repository name: '$REPO'"
echo -e "$INFO [INFO] Block storage class: '$DEFAULT_BLOCK_STORAGE'"
echo -e "$INFO [INFO] File storage class: '$DEFAULT_FILE_STORAGE'"
echo -e "$INFO [INFO] HA is enabled: '$HA_ENABLED'"

divider

if ! oc get storageclass $DEFAULT_BLOCK_STORAGE; then
  echo -e "$CROSS [ERROR] The block storage class (-g) of \"$DEFAULT_BLOCK_STORAGE\" could not be found:"
  oc get storageclasses
  exit 1
fi

if ! oc get storageclass $DEFAULT_FILE_STORAGE; then
  echo -e "$CROSS [ERROR] The file storage class (-f) of \"$DEFAULT_FILE_STORAGE\" could not be found:"
  oc get storageclasses
  exit 1
fi

echo -e "$TICK [SUCCESS] Storage classes \"$DEFAULT_BLOCK_STORAGE\" and \"$DEFAULT_FILE_STORAGE\" both exist"

divider

if ! oc project $NAMESPACE >/dev/null 2>&1; then
  echo -e "$CROSS [ERROR] The namespace '$NAMESPACE' does not exist"
  exit 1
else
  echo -e "$TICK [SUCCESS] The namespace '$NAMESPACE' exists"
fi

divider

# switch namespace
oc project $NAMESPACE

divider

echo -e "$INFO [INFO] Create PVCs"
YAML=$(cat $CURRENT_DIR/pvcs.yaml |
  sed "s#{{DEFAULT_FILE_STORAGE}}#$DEFAULT_FILE_STORAGE#g;" |
  sed "s#{{DEFAULT_BLOCK_STORAGE}}#$DEFAULT_BLOCK_STORAGE#g;")
OCApplyYAML "$NAMESPACE" "$YAML"

divider

# create the pipeline to run tasks to build and deploy to test using apic
echo -e "$INFO [INFO] Create the pipeline in '$NAMESPACE' namespace"
YAML=$(cat $CURRENT_DIR/pipeline-apic.yaml |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" |
  sed "s#{{FORKED_REPO}}#$REPO#g;" |
  sed "s#{{BRANCH}}#$BRANCH#g;" |
  sed "s#{{HA_ENABLED}}#$HA_ENABLED#g;" |
  sed "s#{{DEFAULT_FILE_STORAGE}}#$DEFAULT_FILE_STORAGE#g;" |
  sed "s#{{DEFAULT_BLOCK_STORAGE}}#$DEFAULT_BLOCK_STORAGE#g;")
OCApplyYAML "$NAMESPACE" "$YAML"

divider

echo -e "$INFO [INFO] Waiting for webhook to appear in the '$NAMESPACE' namespace..."

time=0
while ! oc get route -n $NAMESPACE el-main-trigger-route --template='http://{{.spec.host}}'; do
  if [ $time -gt 5 ]; then
    echo -e "\n$CROSS [ERROR] Timed-out trying to wait for webhook to appear in the '$NAMESPACE' namespace"
    divider
    exit 1
  fi
  echo -e "$INFO [INFO] Waiting for upto 5 minutes for the webhook route to appear for the tekton pipeline trigger in the '$NAMESPACE' namespace. Waited $time minute(s)"
  time=$((time + 1))
  sleep 60
done

WEBHOOK_ROUTE=$(oc get route -n $NAMESPACE el-main-trigger-route --template='http://{{.spec.host}}')
echo -e "\n\n$TICK [INFO] Webhook route in the '$NAMESPACE' namespace: $WEBHOOK_ROUTE"

if [[ -z $WEBHOOK_ROUTE ]]; then
  echo -e "\n$CROSS [ERROR] Failed to get route for the webhook in the '$NAMESPACE' namespace"
  exit 1
fi

echo -e "\n$TICK [SUCCESS] Successfully got route for the webhook in the '$NAMESPACE' namespace"

divider

# print route for webhook
echo -e "$INFO [INFO] Your trigger route for the github webhook: $WEBHOOK_ROUTE"
echo -e "$INFO [INFO] The next step is to add the trigger URL to the forked repository as a webhook with the Content type as 'application/json', which triggers an initial run of the pipeline."
echo -e "$INFO [INFO] To manually trigger a run of the pipeline use:"
echo -e "$INFO [INFO]    curl -X POST $WEBHOOK_ROUTE --header \"Content-Type: application/json\" --data '{\"message\":\"Test run\"}'\n"
echo -e "$TICK  $ALL_DONE Successfully applied all the cicd pipeline resources and requirements in the '$NAMESPACE' namespace for the apic pipeline of the driveway dent deletion demo"

divider
