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
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#   -e : <ELASTIC_NAMESPACE> (string), Namespace for elastic search , Defaults to 'elasticsearch'
#   -p : <POSTGRES_NAMESPACE> (string), Namespace where postgres is setup, Defaults to the value of <NAMESPACE>
#   -o : <OMIT_INITIAL_SETUP> (optional), Parameter to decide if initial setup is to be done or not, Defaults to false
#   -f : <DEFAULT_FILE_STORAGE> (string), Default to 'ibmc-file-gold-gid'
#   -g : <DEFAULT_BLOCK_STORAGE> (string), Default to 'cp4i-block-performance'
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <NAMESPACE> -r <REPO> -b <BRANCH> -e <ELASTIC_NAMESPACE> -p <POSTGRES_NAMESPACE>  -f <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE> -o

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <REPO> -b <BRANCH> -e <ELASTIC_NAMESPACE> -p <POSTGRES_NAMESPACE>  -f <DEFAULT_FILE_STORAGE> -g <DEFAULT_BLOCK_STORAGE> [-o]"
  divider
  exit 1
}

NAMESPACE="cp4i"
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
SUFFIX="eei"
POSTGRES_NAMESPACE=$NAMESPACE
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
BRANCH="main"
INFO="\xE2\x84\xB9"
MISSING_PARAMS="false"
ELASTIC_NAMESPACE=$NAMESPACE
OMIT_INITIAL_SETUP=false
DEFAULT_FILE_STORAGE="ibmc-file-gold-gid"
DEFAULT_BLOCK_STORAGE="cp4i-block-performance"

while getopts "n:r:b:e:p:of:g:" opt; do
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
  e)
    ELASTIC_NAMESPACE="$OPTARG"
    ;;
  p)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  o)
    OMIT_INITIAL_SETUP=true
    ;;
  f)
    DEFAULT_FILE_STORAGE="$OPTARG"
    ;;
  g)
    DEFAULT_BLOCK_STORAGE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for event enabled insurance demo is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${REPO// /}" ]]; then
  echo -e "$CROSS [ERROR] Repository name for event enabled insurance demo is empty. Please provide a value for '-r' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${BRANCH// /}" ]]; then
  echo -e "$CROSS [ERROR] Branch name for the repository for event enabled insurance demo is empty. Please provide a value for '-b' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${ELASTIC_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for elastic search for event enabled insurance demo is empty. Please provide a value for '-e' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${POSTGRES_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace for postgres for event enabled insurance demo is empty. Please provide a value for '-p' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_FILE_STORAGE// /}" ]]; then
  echo -e "$CROSS [ERROR] File storage type for event enabled insurance demo is empty. Please provide a value for '-f' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DEFAULT_BLOCK_STORAGE// /}" ]]; then
  echo -e "$CROSS [ERROR] Block storage type for for event enabled insurance demo is empty. Please provide a value for '-g' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

CURRENT_DIR=$(dirname $0)
echo -e "$INFO [INFO] Current directory for the event enabled insurance demo: '$CURRENT_DIR'"
echo -e "$INFO [INFO] Namespace for running event enabled insurance demo prereqs: '$NAMESPACE'"
echo -e "$INFO [INFO] Namespace for postgres for the event enabled insurance demo: '$POSTGRES_NAMESPACE'"
echo -e "$INFO [INFO] Namespace for elastic search for the event enabled insurance demo: '$ELASTIC_NAMESPACE'"
echo -e "$INFO [INFO] Suffix for the postgres for the event enabled insurance demo: '$SUFFIX'"
echo -e "$INFO [INFO] Samples repository for the event enabled insurance demo: '$REPO'"
echo -e "$INFO [INFO] Samples repo branch for the event enabled insurance demo: '$BRANCH'"
echo -e "$INFO [INFO] File storage type for the event enabled insurance demo: '$DEFAULT_FILE_STORAGE'"
echo -e "$INFO [INFO] Block storage type for the event enabled insurance demo: '$DEFAULT_BLOCK_STORAGE'"
echo -e "$INFO [INFO] Omit initial setup for the event enabled insurance demo: '$OMIT_INITIAL_SETUP'"

divider

oc project $NAMESPACE

divider

echo -e "[INFO] Checking if tekton-cli is pre-installed...\n"
tknInstalled=false
TKN=tkn
$TKN version

if [ $? -ne 0 ]; then
  tknInstalled=false
else
  tknInstalled=true
fi

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

divider

if [[ "$OMIT_INITIAL_SETUP" == "false" ]]; then
  echo -e "$INFO [INFO] Installing OCP pipelines..."
  if ! $CURRENT_DIR/../products/bash/install-ocp-pipeline.sh; then
    echo -e "$CROSS [ERROR] Failed to install OCP pipelines\n"
    exit 1
  else
    echo -e "$TICK [SUCCESS] Successfully installed OCP pipelines"
  fi #install-ocp-pipeline.sh

  divider

  echo -e "$INFO [INFO] Configuring secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the eei demo..."
  if ! $CURRENT_DIR/../products/bash/configure-ocp-pipeline.sh -n $NAMESPACE; then
    echo -e "\n$CROSS [ERROR]: Failed to create secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the eei demo\n"
    exit 1
  else
    echo -e "$TICK [SUCCESS]: Successfully configured secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace for the eei demo"
  fi #configure-ocp-pipeline.sh

  divider
fi

echo -e "$INFO [INFO] Generating user, database name and password for the postgres database in the '$NAMESPACE' namespace"
DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_USER=$(echo ${NAMESPACE}_sor_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
DB_PASS=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  echo
)
PASSWORD_ENCODED=$(echo -n $DB_PASS | base64)

echo -e "$INFO [INFO] Creating a secret for the lifecycle simulator app to connect to postgres"
# everything inside 'data' must be in the base64 encoded form
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $NAMESPACE
  name: postgres-credential-$SUFFIX
type: Opaque
data:
  password: $PASSWORD_ENCODED
EOF

divider

echo -e "$INFO [INFO] Configuring postgres in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'\n"
if ! $CURRENT_DIR/../products/bash/configure-postgres-db.sh -n $POSTGRES_NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -e $SUFFIX; then
  echo -e "$CROSS [ERROR] Failed to configure postgres in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Successfully configured postgres in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #configure-postgres-db.sh

divider

REPLICATION_USER=$(echo ${NAMESPACE}_sor_replication_${SUFFIX} | sed 's/-/_/g')
REPLICATION_PASSWORD=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  echo
)
REPLICATION_PASSWORD_ENCODED=$(echo -n $REPLICATION_PASSWORD | base64)

echo -e "$INFO [INFO] Creating replication user"
oc exec -n $POSTGRES_NAMESPACE -i $DB_POD -- psql -d $DB_NAME <<EOF
CREATE ROLE $REPLICATION_USER REPLICATION LOGIN PASSWORD $(echo "'$REPLICATION_PASSWORD'");
ALTER USER $REPLICATION_USER WITH PASSWORD $(echo "'$REPLICATION_PASSWORD'");
GRANT ALL PRIVILEGES ON TABLE quotes TO $REPLICATION_USER;
CREATE PUBLICATION db_eei_quotes FOR TABLE quotes;
EOF

echo -e "\n$INFO [INFO] Creating secret for replication user"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $NAMESPACE
  name: eei-postgres-replication-credential
type: Opaque
stringData:
  connector.properties: |-
    dbName: $DB_NAME
    dbUsername: $REPLICATION_USER
    dbPassword: $REPLICATION_PASSWORD
EOF

echo -e "\n$INFO [INFO] Creating ace postgres configuration and policy in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
if ! $CURRENT_DIR/../products/bash/create-ace-config.sh -n $NAMESPACE -u $DB_USER -d $DB_NAME -p $DB_PASS -s $SUFFIX -g $POSTGRES_NAMESPACE; then
  echo -e "\n$CROSS [ERROR] Failed to configure ace in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Successfully configured ace in the '$NAMESPACE' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #create-ace-config.sh

divider
echo -e "$TICK $ALL_DONE [SUCCESS] All prerequisites for the event enabled insurance demo have been applied successfully $ALL_DONE $TICK"
divider

time=0
echo -e "$INFO [INFO] Waiting for upto 120 minutes for git-clone cluster task to be available before creating the pipeline and the pipelinerun..."
GIT_CLONE_CLUSTER_TASK=$(oc get clustertask git-clone)
RESULT_GIT_CLONE_CLUSTER_TASK=$(echo $?)
while [ "$RESULT_GIT_CLONE_CLUSTER_TASK" -ne "0" ]; do
  if [ $time -gt 120 ]; then
    echo -e "$CROSS [ERROR] Timed-out waiting for 'git-clone' cluster task to be available"
    divider
    exit 1
  fi

  $TKN clustertask ls | grep git-clone
  echo -e "\n$INFO [INFO] The cluster task 'git-clone' is not yet available, waiting for upto 120 minutes. Waited $time minute(s)."
  time=$((time + 1))
  sleep 60
  GIT_CLONE_CLUSTER_TASK=$(oc get clustertask git-clone)
  RESULT_GIT_CLONE_CLUSTER_TASK=$(echo $?)
done

echo -e "\n$INFO [INFO] Cluster task 'git-clone' is now available\n"
$TKN clustertask ls | grep git-clone

divider

echo -e "$INFO [INFO] Installing Elastic search operator and Elastic search instance..."
if ! $CURRENT_DIR/setup-elastic-search.sh -n $NAMESPACE -e $ELASTIC_NAMESPACE; then
  echo -e "\n$CROSS [ERROR] Failed to install elastic search in the '$ELASTIC_NAMESPACE' namespace and configure it in the '$NAMESPACE' namespace"
  exit 1
else
  echo -e "\n$TICK [SUCCESS] Successfully installed elastic search in the '$ELASTIC_NAMESPACE' namespace and configured it in the '$NAMESPACE' namespace"
fi #setup-elastic-search.sh

divider

echo -e "$INFO [INFO] Building and deploying the EEI apps ..."
if ! $CURRENT_DIR/build/build.sh -n $NAMESPACE -r $REPO -b $BRANCH -t $TKN -f "$DEFAULT_FILE_STORAGE" -g "$DEFAULT_BLOCK_STORAGE"; then
  echo -e "\n$CROSS [ERROR] Failed to build/deploy the EEI apps in the '$NAMESPACE' namespace"
  exit 1
else
  echo -e "$TICK [SUCCESS] Successfully built and deployed the EEI apps in the '$NAMESPACE' namespace"
fi #build/build.sh

divider
