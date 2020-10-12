#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <namespace> -r <REPO> -b <BRANCH>

function usage() {
  echo "Usage: $0 -n <namespace> -r <REPO> -b <BRANCH>"
  exit 1
}

namespace="cp4i"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
SUFFIX="eei"
POSTGRES_NAMESPACE="postgres"
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
BRANCH="main"
ELASTIC_NAMESPACE="elasticsearch"

while getopts "n:r:b:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    REPO="$OPTARG"
    ;;
  b)
    BRANCH="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${namespace// }" || -z "${REPO// }" || -z "${BRANCH// }" ]]; then
  echo -e "$cross ERROR: Mandatory parameters are empty"
  usage
fi

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"
echo "INFO: Repo: '$REPO'"
echo "INFO: Branch: '$BRANCH'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

oc project $namespace

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Checking if tekton-cli is pre-installed..."
tknInstalled=false
TKN=tkn
$TKN version

if [ $? -ne 0 ]; then
  tknInstalled=false
else
  tknInstalled=true
fi

if [[ "$tknInstalled" == "false" ]]; then
  echo "INFO: Installing tekton cli..."
  if [[ $(uname) == Darwin ]]; then
    echo "INFO: Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew tap tektoncd/tools
    brew install tektoncd/tools/tektoncd-cli
  else
    echo "INFO: Installing on Linux"
    # Get the tar
    curl -LO https://github.com/tektoncd/cli/releases/download/v0.12.0/tkn_0.12.0_Linux_x86_64.tar.gz
    # Extract tkn to current directory
    tar xvzf tkn_0.12.0_Linux_x86_64.tar.gz -C . tkn
    untarStatus=$(echo $?)
    if [[ "$untarStatus" -ne 0 ]]; then
      echo -e "\n$cross ERROR: Could not extract the tar for tkn"
      exit 1
    fi

    chmod +x ./tkn
    chmodStatus=$(echo $?)
    if [[ "$chmodStatus" -ne 0 ]]; then
      echo -e "\n$cross ERROR: Could not make the 'tkn' executable"
      exit 1
    fi

    TKN=./tkn
  fi
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Installing OCP pipelines..."
if ! ${CURRENT_DIR}/../products/bash/install-ocp-pipeline.sh; then
  echo -e "$cross ERROR: Failed to install OCP pipelines\n"
  exit 1
else
  echo -e "$tick INFO: Successfully installed OCP pipelines"
fi #install-ocp-pipeline.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Configuring secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo..."
if ! ${CURRENT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}; then
  echo -e "\n$cross ERROR: Failed to create secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo\n"
  exit 1
else
  echo -e "$tick INFO: Successfully configured secrets and permissions related to ocp pipelines in the '$namespace' namespace for the eei demo"
fi #configure-ocp-pipeline.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Setting up the prerequisites for the event enabled insurance demo in the '$namespace' namespace...\n"
echo "INFO: Generating user, database name and password for the postgres database in the '$namespace' namespace"
DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_USER=$(echo ${namespace}_sor_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_PASS=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  echo
)
PASSWORD_ENCODED=$(echo -n ${DB_PASS} | base64)

echo "INFO: Creating a secret for the lifecycle simulator app to connect to postgres"
# everything inside 'data' must be in the base64 encoded form
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $namespace
  name: postgres-credential-$SUFFIX
type: Opaque
data:
  password: ${PASSWORD_ENCODED}
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Configuring postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'\n"
if ! ${CURRENT_DIR}/../products/bash/configure-postgres-db.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS -e $SUFFIX; then
  echo -e "$cross ERROR: Failed to configure postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' amd suffix '$SUFFIX'"
  exit 1
else
  echo -e "$tick INFO: Successfully configured postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #configure-postgres-db.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

REPLICATION_USER=$(echo ${namespace}_sor_replication_${SUFFIX} | sed 's/-/_/g')
REPLICATION_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
REPLICATION_PASSWORD_ENCODED=$(echo -n ${REPLICATION_PASSWORD} | base64)

echo "INFO: Creating replication user"
oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD -- psql -d $DB_NAME << EOF
CREATE ROLE $REPLICATION_USER REPLICATION LOGIN PASSWORD `echo "'${REPLICATION_PASSWORD}'"`;
ALTER USER $REPLICATION_USER WITH PASSWORD `echo "'${REPLICATION_PASSWORD}'"`;
GRANT ALL PRIVILEGES ON TABLE quotes TO $REPLICATION_USER;
CREATE PUBLICATION db_eei_quotes FOR TABLE quotes;
EOF

echo -e "\nINFO: Creating secret for replication user"
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $namespace
  name: eei-postgres-replication-credential
type: Opaque
stringData:
  connector.properties: |-
    dbName: ${DB_NAME}
    dbUsername: ${REPLICATION_USER}
    dbPassword: ${REPLICATION_PASSWORD}
EOF

echo -e "\nINFO: Creating ace postgres configuration and policy in the namespace '$namespace' with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
if ! ${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS -s $SUFFIX; then
  echo -e "\n$cross ERROR: Failed to configure ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$tick INFO: Successfully configured ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #create-ace-config.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the event enabled insurance demo have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

time=0
echo "INFO: Waiting for upto 10 minutes for git-clone cluster task to be available before creating the pipeline and the pipelinerun..."
GIT_CLONE_CLUSTER_TASK=$(oc get clustertask git-clone)
RESULT_GIT_CLONE_CLUSTER_TASK=$(echo $?)
while [ "$RESULT_GIT_CLONE_CLUSTER_TASK" -ne "0" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Timed-out waiting for 'git-clone' cluster task to be available"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  $TKN clustertask ls | grep git-clone
  echo -e "\nINFO: The cluster task 'git-clone' is not yet available, waiting for upto 10 minutes. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
  GIT_CLONE_CLUSTER_TASK=$(oc get clustertask git-clone)
  RESULT_GIT_CLONE_CLUSTER_TASK=$(echo $?)
done

echo -e "\nINFO: Cluster task 'git-clone' is now available\n"
$TKN clustertask ls | grep git-clone

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Installing Elastic search operator and Elastic search instance..."
if ! ${CURRENT_DIR}/setup-elastic-search.sh -n ${namespace} -e $ELASTIC_NAMESPACE; then
  echo -e "\n$cross ERROR: Failed to install elastic search in the '$ELASTIC_NAMESPACE' namespace and configure it in the '$namespace' namespace"
  exit 1
else
  echo -e "\n$tick INFO: Successfully installed elastic search in the '$ELASTIC_NAMESPACE' namespace and configured it in the '$namespace' namespace"
fi #setup-elastic-search.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Building and deploying the EEI apps ..."
if ! ${CURRENT_DIR}/build/build.sh -n ${namespace} -r $REPO -b $BRANCH -t $TKN; then
  echo -e "\n$cross ERROR: Failed to build/deploy the EEI apps in the '$namespace' namespace"
  exit 1
else
  echo -e "\n$tick INFO: Successfully built and deplopyed the EEI apps in the '$namespace' namespace"
fi #build/build.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
