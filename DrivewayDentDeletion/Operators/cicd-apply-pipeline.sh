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
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -r : <repo> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <branch> (string), Defaults to 'master'
#
#   With defaults values
#     ./test-api-e2e.sh
#
#   With overridden values
#     ./test-api-e2e.sh -n <namespace> -r <repo> -b <branch>

function usage() {
  echo "Usage: $0 -n <namespace> -r <repo> -b <branch>"
}

# default vars
namespace="cp4i"
branch="master"
repo="https://github.com/IBM/cp4i-deployment-samples.git"
tick="\xF0\x9F\x98\x81"
cross="\xF0\x9F\x92\xA9"
all_done="\xF0\x9F\x92\xAF"
sum=0

while getopts "n:r:b:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    repo="$OPTARG"
    ;;
  b)
    branch="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

DEV_NAMESPACE=$namespace-ddd-dev

echo "INFO: Namespace: $namespace"
echo "INFO: Dev namespace: $DEV_NAMESPACE"
echo "INFO: Branch: $branch"
echo "INFO: Repo: $repo"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# switch namespace
oc project $namespace

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# apply pvc for buildah tasks
echo "INFO: Apply pvc for buildah tasks"
if oc apply -f cicd-pvc.yaml; then
  printf "$tick "
  echo "Successfully applied pvc"
else
  printf "$cross "
  echo "Failed to apply pvc"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create service accounts
echo "INFO: Create service accounts"
if cat cicd-service-accounts.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
  printf "$tick "
  echo "Successfully applied service accounts"
else
  printf "$cross "
  echo "Failed to apply service accounts"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create roles for tasks
echo "INFO: Create roles for tasks"
if oc apply -f cicd-roles.yaml; then
  printf "$tick "
  echo "Successfully created roles for tasks"
else
  printf "$cross "
  echo "Failed to create roles for tasks"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create role bindings for roles
echo "INFO: Create role bindings for roles"
if cat cicd-rolebindings.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
  printf "$tick "
  echo "Successfully applied role bindings for roles"
else
  printf "$cross "
  echo "Failed to apply role bindings for roles"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create pipeline resources
echo "INFO: Create pipeline resources"
if cat cicd-pipeline-resources.yaml |
  sed "s#{{FORKED_REPO}}#$repo#g;" |
  sed "s#{{BRANCH}}#$branch#g;" |
  oc apply -f -; then
  printf "$tick "
  echo "Successfully applied pipeline resources"
else
  printf "$cross "
  echo "Failed to apply pipeline resources"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create tekton tasks
echo "INFO: Create tekton tasks"
if cat cicd-tasks.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
  printf "$tick "
  echo "Successfully applied tekton tasks"
else
  printf "$cross "
  echo "Failed to apply tekton tasks"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create the pipeline to run tasks to build, deploy to dev, test e2e and push to test namespace
echo "INFO: Create the pipeline to run tasks to build, deploy to dev, test e2e and push to test namespace"
if oc apply -f cicd-pipeline.yaml; then
  printf "$tick "
  echo "Successfully applied the pipeline to run tasks to build, deploy to dev, test e2e and push to test namespace"
else
  printf "$cross "
  echo "Failed to apply the pipeline to run tasks to build, deploy to dev, test e2e and push to test namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create the trigger template containing the pipelinerun
echo "INFO: Create the trigger template containing the pipelinerun"
if oc apply -f cicd-trigger-template.yaml; then
  printf "$tick "
  echo "Successfully applied the trigger template containing the pipelinerun"
else
  printf "$cross "
  echo "Failed to apply the trigger template containing the pipelinerun"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

# create the event listener and route for webhook
echo "INFO : Create the event listener and route for webhook"
if oc apply -f cicd-events-routes.yaml; then
  printf "$tick "
  echo "Successfully created the event listener and route for webhook"
else
  printf "$cross "
  echo "Failed to apply the event listener and route for webhook"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

WEBHOOK_ROUTE=$(oc get route -n $namespace el-main-trigger --template='http://{{.spec.host}}')
echo "INFO: Webhook route got is: $WEBHOOK_ROUTE"

if [[ -z $WEBHOOK_ROUTE ]]; then
  printf "$cross "
  echo "Failed to get route for the webhook"
  sum=$((sum + 1))
else
  printf "$tick "
  echo "Successfully got route for the webhook"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

if [[ $sum -gt 0 ]]; then
  echo "WARNING: Creating the webhook is not recommended as some resources have not been applied successfully"
else
  # print route for webbook
  echo "INFO: Your trigger route for the git webhook is: $WEBHOOK_ROUTE"
  echo "INFO: Add the trigger URL to the repo as a webhook with the Content type as 'application/json', which triggers an initial run of the pipeline."
  printf "$tick  $all_done "
  echo "Successfully applied all the cicd pipeline resources and requirements"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
