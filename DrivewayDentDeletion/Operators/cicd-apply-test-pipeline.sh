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
#     ./cicd-apply-test-pipeline.sh
#
#   With overridden values
#     ./cicd-apply-test-pipeline.sh -n <namespace> -r <repo> -b <branch>

function usage() {
  echo "Usage: $0 -n <namespace> -r <repo> -b <branch>"
  exit 1
}

# default vars
namespace="cp4i"
branch="master"
repo="https://github.com/IBM/cp4i-deployment-samples.git"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
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

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

if ! oc project $namespace >/dev/null 2>&1 ; then
  echo "ERROR: The dev namespace '$namespace' does not exist"
  exit 1
fi

if ! oc project $namespace-ddd-test >/dev/null 2>&1 ; then
  echo "ERROR: The test namespace '$namespace-ddd-test' does not exist"
  exit 1
fi

echo "INFO: Namespace passed: $namespace"
echo "INFO: Dev Namespace: $namespace"
echo "INFO: Test Namespace: $namespace-ddd-test"
echo "INFO: Branch: $branch"
echo "INFO: Repo: $repo"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# switch namespace
oc project $namespace

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# apply pvc for buildah tasks
echo "INFO: Apply pvc for buildah tasks"
if oc apply -f $CURRENT_DIR/cicd-test/cicd-pvc.yaml; then
  printf "$tick "
  echo "Successfully applied pvc in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply pvc in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create service accounts
echo "INFO: Create service accounts"
if cat $CURRENT_DIR/cicd-test/cicd-service-accounts.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    printf "$tick "
    echo "Successfully applied service accounts in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply service accounts in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create roles for tasks
echo "INFO: Create roles for tasks"
if cat $CURRENT_DIR/cicd-test/cicd-roles.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    printf "$tick "
    echo "Successfully created roles for tasks in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to create roles for tasks in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create role bindings for roles
echo "INFO: Create role bindings for roles"
if cat $CURRENT_DIR/cicd-test/cicd-rolebindings.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    printf "$tick "
    echo "Successfully applied role bindings for roles in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply role bindings for roles in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create tekton tasks
echo "INFO: Create tekton tasks"
if cat $CURRENT_DIR/cicd-test/cicd-tasks.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    printf "$tick "
    echo "Successfully applied tekton tasks in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply tekton tasks in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create the pipeline to run tasks to build, deploy, test e2e and push to test namespace
echo "INFO: Create the pipeline to run tasks to build, deploy, test e2e in '$namespace' and '$namespace-ddd-test' namespace"
if cat $CURRENT_DIR/cicd-test/cicd-pipeline.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  sed "s#{{FORKED_REPO}}#$repo#g;" |
  sed "s#{{BRANCH}}#$branch#g;" |
  oc apply -f -; then
    printf "$tick "
    echo "Successfully applied the pipeline to run tasks to build, deploy, test e2e in '$namespace' and '$namespace-ddd-test' namespace"
else
  printf "$cross "
  echo "Failed to apply the pipeline to run tasks to build, deploy test e2e in '$namespace' and '$namespace-ddd-test' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create the trigger template containing the pipelinerun
echo "INFO: Create the trigger template containing the pipelinerun in the '$namespace' namespace"
if oc apply -f $CURRENT_DIR/cicd-test/cicd-trigger-template.yaml; then
  printf "$tick "
  echo "Successfully applied the trigger template containing the pipelinerun in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply the trigger template containing the pipelinerun in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create the event listener and route for webhook
echo "INFO : Create the event listener and route for webhook in the '$namespace' namespace"
if oc apply -f $CURRENT_DIR/cicd-test/cicd-events-routes.yaml; then
  printf "$tick "
  echo "Successfully created the event listener and route for webhook in the '$namespace' namespace"
else
  printf "$cross "
  echo "Failed to apply the event listener and route for webhook in the '$namespace' namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Waiting for webhook to appear in the '$namespace' namespace...\n"

time=0
while ! oc get route -n $namespace el-main-trigger-route --template='http://{{.spec.host}}'; do
  if [ $time -gt 5 ]; then
    echo "ERROR: Timed-out trying to wait for webhook to appear in the '$namespace' namespace"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi
  echo "INFO: Waiting for upto 5 minutes for the webhook route to appear for the tekton pipeline trigger in the '$namespace' namespace. Waited $time minute(s)"
  time=$((time + 1))
  sleep 60
done

WEBHOOK_ROUTE=$(oc get route -n $namespace el-main-trigger-route --template='http://{{.spec.host}}')
echo -e "\n\nINFO: Webhook route in the '$namespace' namespace: $WEBHOOK_ROUTE"

if [[ -z $WEBHOOK_ROUTE ]]; then
  printf "$cross "
  echo "Failed to get route for the webhook in the '$namespace' namespace"
  sum=$((sum + 1))
else
  printf "$tick "
  echo "Successfully got route for the webhook in the '$namespace' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

if [[ $sum -gt 0 ]]; then
  echo "ERROR: Creating the webhook is not recommended as some resources have not been applied successfully in the '$namespace' namespace"
  exit 1
else
  # print route for webbook
  echo "INFO: Your trigger route for the github webhook is: $WEBHOOK_ROUTE"
  echo -e "\nINFO: The next step is to add the trigger URL to the forked repo as a webhook with the Content type as 'application/json', which triggers an initial run of the pipeline.\n"
  printf "$tick  $all_done "
  echo "Successfully applied all the cicd pipeline resources and requirements in the '$namespace' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
