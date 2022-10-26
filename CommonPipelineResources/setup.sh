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
  echo "Usage: $0 -n <NAMESPACE>"
  divider
  exit 1
}

set -e

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../products/bash/utils.sh

NAMESPACE="cp4i"

while getopts "n:" opt; do
  case ${opt} in
    n)
      NAMESPACE="$OPTARG"
      ;;
  \?)
    usage
    ;;
  esac
done

echo -e "$INFO [INFO] Create common tasks"
YAML=$(cat $CURRENT_DIR/cicd-tasks.yaml)
OCApplyYAML "$NAMESPACE" "$YAML"

echo -e "$INFO [INFO] Build command image"

echo -e "[INFO] Checking if tekton-cli is pre-installed...\n"
set +e
tknInstalled=false
TKN=tkn
$TKN version
if [ $? -ne 0 ]; then
  tknInstalled=false
else
  tknInstalled=true
fi

set -e

if [[ "$tknInstalled" == "false" ]]; then
  echo -e "$INFO [INFO] Installing tekton cli..."
  if [[ $(uname) == Darwin ]]; then
    echo -e "$INFO [INFO] Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew tap tektoncd/tools
    brew install tektoncd/tools/tektoncd-cli
  else
    echo -e "$INFO [INFO] Installing on Linux"
    # Get the tar
    curl -LO https://github.com/tektoncd/cli/releases/download/v0.12.0/tkn_0.12.0_Linux_x86_64.tar.gz
    # Extract tkn to current directory
    tar xvzf tkn_0.12.0_Linux_x86_64.tar.gz -C . tkn
    untarStatus=$(echo $?)
    if [[ "$untarStatus" -ne 0 ]]; then
      echo -e "\n$CROSS [ERROR] Could not extract the tar for tkn"
      exit 1
    fi

    chmod +x ./tkn
    chmodStatus=$(echo $?)
    if [[ "$chmodStatus" -ne 0 ]]; then
      echo -e "\n$CROSS [ERROR] Could not make the 'tkn' executable"
      exit 1
    fi

    TKN=./tkn
  fi
fi

echo "INFO: Delete the old pipelineruns"
set +e
oc get pipelinerun -n ${namespace} --no-headers=true 2>/dev/null | awk '/common-build-pipelinerun/{print $1}' | xargs  oc delete pipelinerun -n ${namespace}
set -e

PIPELINERUN_UID=$(
  LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 5
  echo
)
PIPELINE_RUN_NAME="common-build-pipelinerun-${PIPELINERUN_UID}"

echo "INFO: Creating the pipeline to build the command image in '$namespace' namespace"
if cat $CURRENT_DIR/setup-pipeline.yaml |
  sed "s#{{PIPELINE_RUN_NAME}}#$PIPELINE_RUN_NAME#g;" |
  oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied the pipeline"
else
  echo -e "\n$cross ERROR: Failed to apply the pipeline"
  exit 1
fi

divider

pipelinerunSuccess="false"
echo -e "INFO: Displaying the pipelinerun logs in the '$namespace' namespace: \n"
if ! $TKN pipelinerun logs -n $namespace -f $PIPELINE_RUN_NAME; then
  echo -e "\n$cross ERROR: Failed to get the pipelinerun logs successfully"
fi

divider

echo -e "INFO: The pipeline run in the '$namespace' namespace:\n"
oc get pipelinerun -n $namespace $PIPELINE_RUN_NAME

echo -e "\nINFO: The task runs in the '$namespace' namespace:\n"
oc get taskrun -n $namespace

if [[ "$(oc get pipelinerun -n $namespace $PIPELINE_RUN_NAME -o json | jq -r '.status.conditions[0].status')" == "True" ]]; then
  pipelinerunSuccess="true"
fi

if [[ "$pipelinerunSuccess" == "false" ]]; then
  echo -e "\n$cross ERROR: The pipelinerun did not succeed\n"
  exit 1
fi

echo -e "\nINFO: Going ahead to delete the pipelinerun instance to delete the related pods and the pvc"

divider

if oc delete pipelinerun -n $namespace $PIPELINE_RUN_NAME; then
  echo -e "\n$tick INFO: Deleted the pipelinerun with the uid '$PIPELINERUN_UID'"
else
  echo -e "$cross ERROR: Failed to delete the pipelinerun with the uid '$PIPELINERUN_UID'"
fi

divider
