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
#
#   With defaults values
#     ./cicd-apply-dev-pipeline.sh
#
#   With overridden values
#     ./cicd-apply-dev-pipeline.sh -n <NAMESPACE> -r <REPO> -b <BRANCH>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <REPO> -b <BRANCH>"
  divider
  exit 1
}

# default vars
NAMESPACE="cp4i"
BRANCH="main"
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
INFO="\xE2\x84\xB9"
SUM=0
CURRENT_DIR=$(dirname $0)
MISSING_PARAMS="false"

while getopts "n:r:b:" opt; do
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
  echo -e "$CROSS [ERROR] Repository name parameter for dev pipeline of driveway dent deletion demo is empty. Please provide a value for '-r' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${BRANCH// /}" ]]; then
  echo -e "$CROSS [ERROR] Branch name parameter for dev pipeline of driveway dent deletion demo is empty. Please provide a value for '-b' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

echo -e "$INFO [INFO] Current directory for the dev pipeline of the driveway dent deletion demo: '$CURRENT_DIR'"
echo -e "$INFO [INFO] Namespace provided for the dev pipeline of the driveway dent deletion demo: '$NAMESPACE'"
echo -e "$INFO [INFO] Branch name for the dev pipeline of the driveway dent deletion demo: '$BRANCH'"
echo -e "$INFO [INFO] Repository name for the dev pipeline of the driveway dent deletion demo: '$REPO'"

divider

if ! oc project $NAMESPACE >/dev/null 2>&1; then
  echo -e "$CROSS [ERROR] The dev and the test namespace '$NAMESPACE' does not exist"
  exit 1
else
  echo -e "$TICK [SUCCESS] The dev and the test namespace '$NAMESPACE' exists"
fi

divider

# switch namespace
oc project $NAMESPACE

divider

# apply pvc for buildah tasks
echo -e "$INFO [INFO] Apply pvc for buildah tasks for the dev pipeline of the driveway dent deletion demo"
if oc apply -f $CURRENT_DIR/cicd-dev/cicd-pvc.yaml; then
  echo -e "\n$TICK [SUCCESS] Successfully applied pvc in the '$NAMESPACE' namespace"
else
  echo -e "\n$CROSS [ERROR] Failed to apply pvc in the '$NAMESPACE' namespace"
  SUM=$((SUM + 1))
fi

divider

# create tekton tasks
TRACING="-t -z $NAMESPACE"
echo -e "$INFO [INFO] Create tekton tasks for the dev pipeline of the driveway dent deletion demo"
if cat $CURRENT_DIR/../../CommonPipelineResources/cicd-tasks.yaml |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" |
  sed "s#{{TRACING}}#$TRACING#g;" |
  oc apply -f -; then
  echo -e "\n$TICK [SUCCESS] Successfully applied tekton tasks in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
else
  echo -e "\n$CROSS [ERROR] Failed to apply tekton tasks in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
  SUM=$((SUM + 1))
fi

divider

# create the pipeline to run tasks to build and deploy to dev
echo -e "$INFO [INFO] Create the pipeline to run tasks for the dev pipeline of the driveway dent deletion demo in '$NAMESPACE' namespace"
if cat $CURRENT_DIR/cicd-dev/cicd-pipeline.yaml |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" |
  sed "s#{{FORKED_REPO}}#$REPO#g;" |
  sed "s#{{BRANCH}}#$BRANCH#g;" |
  oc apply -f -; then
  echo -e "\n$TICK [SUCCESS] Successfully applied the pipeline to run tasks to build and deploy to '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
else
  echo -e "\n$CROSS [ERROR] Failed to apply the pipeline to run tasks to build and deploy to '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
  SUM=$((SUM + 1))
fi

divider

# create the trigger template containing the pipelinerun
echo -e "$INFO [INFO] Create the trigger template for the dev pipeline of the driveway dent deletion demo in the '$NAMESPACE' namespace"
if oc apply -f $CURRENT_DIR/cicd-dev/cicd-trigger-template.yaml; then
  echo -e "\n$TICK [SUCCESS] Successfully applied the trigger template containing the pipelinerun in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
else
  echo -e "\n$CROSS [ERROR] Failed to apply the trigger template containing the pipelinerun in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
  SUM=$((SUM + 1))
fi

divider

# create the event listener and route for webhook
echo "INFO : Create the event listener and route for webhook for the dev pipeline of the driveway dent deletion demo in the '$NAMESPACE' namespace"
if oc apply -f $CURRENT_DIR/cicd-dev/cicd-events-routes.yaml; then
  echo -e "\n$TICK [SUCCESS] Successfully created the event listener and route for webhook in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
else
  echo -e "\n$CROSS [ERROR] Failed to apply the event listener and route for webhook in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
  SUM=$((SUM + 1))
fi

divider

echo -e "$INFO [INFO] Waiting for webhook to appear in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo..."

time=0
while ! oc get route -n $NAMESPACE el-main-trigger-route --template='http://{{.spec.host}}'; do
  if [ $time -gt 5 ]; then
    echo -e "\n$CROSS [ERROR] Timed-out trying to wait for webhook to appear in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
    divider
    exit 1
  fi
  echo -e "$INFO [INFO] Waiting for upto 5 minutes for the webhook route to appear for the tekton pipeline trigger in the '$NAMESPACE' namespace. Waited $time minute(s)"
  time=$((time + 1))
  sleep 60
done

WEBHOOK_ROUTE=$(oc get route -n $NAMESPACE el-main-trigger-route --template='http://{{.spec.host}}')
echo -e "\n\n$TICK [INFO] Webhook route in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo: $WEBHOOK_ROUTE"

if [[ -z $WEBHOOK_ROUTE ]]; then
  echo -e "\n$CROSS [ERROR] Failed to get route for the webhook in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
  SUM=$((SUM + 1))
else
  echo -e "\n$TICK [SUCCESS] Successfully got route for the webhook in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
fi

divider

if [[ $SUM -gt 0 ]]; then
  echo -e "$CROSS [ERROR] Creating the webhook is not recommended as some resources have not been applied successfully in the '$NAMESPACE' namespace"
  exit 1
else
  # print route for webhook
  echo -e "$INFO [INFO] Your trigger route for the github webhook for the dev pipeline of the driveway dent deletion demo is: $WEBHOOK_ROUTE"
  echo -e "\n$INFO [INFO] The next step is to add the trigger URL to the forked repository as a webhook with the Content type as 'application/json', which triggers an initial run of the pipeline.\n"
  echo -e "$TICK  $ALL_DONE Successfully applied all the cicd pipeline resources and requirements in the '$NAMESPACE' namespace for the dev pipeline of the driveway dent deletion demo"
fi

divider
