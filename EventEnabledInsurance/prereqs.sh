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
ACE_CONFIGURATION_NAME="ace-policyproject-$SUFFIX"
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
BRANCH="main"

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
    exit
    ;;
  esac
done

if [[ -z "${namespace// }" || -z "${REPO// }" || -z "${BRANCH// }" ]]; then
  echo -e "$cross ERROR: Some or all mandatory parameters are empty"
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

echo -e "\nINFO: Checking if tekton-cli is is pre-installed..."
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

  echo "INFO: Creating a secret for the lifecycle simulator app to conenct to postgres"
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
if ! ${CURRENT_DIR}/../products/bash/create-postgres-db.sh -n ${POSTGRES_NAMESPACE} -u $DB_USER -d $DB_NAME -p $DB_PASS; then
  echo -e "$cross ERROR: Failed to configure postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' amd suffix '$SUFFIX'"
  exit 1
else
  echo -e "$tick INFO: Successfully configured postgres in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #create-postgres-db.sh

echo -e "\nINFO: Creating the table 'QUOTES' and in the database '$DB_NAME' with the username '$DB_USER' in the '$namespace' namespace"
if ! oc exec -n $POSTGRES_NAMESPACE -it $DB_POD \
  -- psql -U $DB_USER -d $DB_NAME -c \
  "
  CREATE TABLE IF NOT EXISTS QUOTES (
    QuoteID SERIAL PRIMARY KEY NOT NULL,
    Source VARCHAR(20),
    Name VARCHAR(100),
    EMail VARCHAR(100),
    Age INTEGER,
    Address VARCHAR(100),
    USState VARCHAR(100),
    LicensePlate VARCHAR(100),
    DescriptionOfDamage VARCHAR(100),
    ClaimStatus INTEGER,
    ClaimCost INTEGER
  );
  "; then
  echo -e "\n$cross ERROR: Failed to create the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER' in the namespace '$namespace'"
  exit 1
else
  echo -e "\n$tick INFO: Created the table 'QUOTES' in the database '$DB_NAME' with the username '$DB_USER' in the namespace '$namespace'"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

REPLICATION_USER=$(echo ${namespace}_sor_replication_${SUFFIX} | sed 's/-/_/g')
REPLICATION_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo)
REPLICATION_PASSWORD_ENCODED=$(echo -n ${REPLICATION_PASSWORD} | base64)

echo "INFO: Creating replication user"
oc exec -n ${POSTGRES_NAMESPACE} -i $DB_POD -- psql -d $DB_NAME << EOF
CREATE ROLE $REPLICATION_USER REPLICATION LOGIN PASSWORD `echo "'${REPLICATION_PASSWORD}'"`;
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
if ! ${CURRENT_DIR}/../products/bash/create-ace-config.sh -n ${namespace} -u $DB_USER -d $DB_NAME -p $DB_PASS -a $ACE_CONFIGURATION_NAME; then
  echo -e "\n$cross ERROR: Failed to configure ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
  exit 1
else
  echo -e "\n$tick INFO: Successfully configured ace in the '$namespace' namespace with the user '$DB_USER' and database name '$DB_NAME' and suffix '$SUFFIX'"
fi #create-ace-config.sh

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the event enabled insurance demo have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating pvc for eei quote lifecycle simulator app in the '$namespace' namespace"
if oc apply -n $namespace -f $CURRENT_DIR/QuoteLifecycleSimulator/simulator-pipeline-resources/simulator-pvc.yaml; then
  echo -e "\n$tick INFO: Successfully created the pvc for eei quote lifecycle simulator app in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to create the pvc for eei quote lifecycle simulator app in the '$namespace' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create common service accounts
echo "INFO: Create common service accounts"
if cat $CURRENT_DIR/../CommonPipelineResources/cicd-service-accounts.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    echo -e "\n$tick INFO: Successfully applied common service accounts in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply common service accounts in the '$namespace' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create common roles for tasks
echo "INFO: Create common roles for tasks"
if cat $CURRENT_DIR/../CommonPipelineResources/cicd-roles.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
   echo -e "\n$tick INFO: Successfully created roles for tasks in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to create roles for tasks in the '$namespace' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create common role bindings for roles
echo "INFO: Create role bindings for roles"
if cat $CURRENT_DIR/../CommonPipelineResources/cicd-rolebindings.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    echo -e "\n$tick INFO: Successfully applied role bindings for roles in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply role bindings for roles in the '$namespace' namespace"
fi #cicd-rolebindings.yaml

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating roles for creating deployment in the '$namespace' namespace for simulator app"
if oc apply -f $CURRENT_DIR/QuoteLifecycleSimulator/simulator-pipeline-resources/simulator-roles.yaml; then
    echo -e "\n$tick INFO: Successfully created roles for creaating deployment in the '$namespace' namespace for simulator app"
else
  echo -e "\n$cross ERROR: Failed to create roles for creaating deployment in the '$namespace' namespace for simulator app"
  exit 1
fi #simulator-roles.yaml

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating rolebinding for creating deployment in the '$namespace' namespace for creating simulator app"
if cat $CURRENT_DIR/QuoteLifecycleSimulator/simulator-pipeline-resources/simulator-rolebindings.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -f -; then
    echo -e "\n$tick INFO: Successfully created rolebinding for creating deployment in the '$namespace' namespace for simulator app"
else
  echo -e "\n$cross ERROR: Failed to create rolebinding for creating deployment in the '$namespace' namespace for simulator app"
  exit 1
fi #simulator-rolebindings.yaml

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Waiting 2 minutes for all cluster tasks to be available before creating the pipeline and the pipelinerun..."
sleep 120

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating the pipeline to build and deploy the simulator app in '$namespace' namespace"
if cat $CURRENT_DIR/QuoteLifecycleSimulator/simulator-pipeline-resources/simulator-pipeline.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  sed "s#{{FORKED_REPO}}#$REPO#g;" |
  sed "s#{{BRANCH}}#$BRANCH#g;" |
  oc apply -f -; then
    echo -e "\n$tick INFO: Successfully applied the pipeline to build and deploy the simulator app in in '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply the pipeline to build and deploy the simulator app in in '$namespace' namespace"
  exit 1
fi #simulator-pipeline.yaml 

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

PIPELINERUN_UID=$(
  LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 5
  echo
)

echo "INFO: Creating the pipelinerun for simulator app in the '$namespace' namespace"
if cat $CURRENT_DIR/QuoteLifecycleSimulator/simulator-pipeline-resources/simulator-pipelinerun.yaml |
  sed "s#{{UID}}#$PIPELINERUN_UID#g;" |
  oc apply -f -; then
  echo -e "\n$tick INFO: Successfully applied the pipelinerun for simulator app in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply the pipelinerun for simulator app in the '$namespace' namespace"
  exit 1
fi #simulator-pipelinerun.yaml

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Displaying the pipelinerun logs: \n"
if ! $TKN pipelinerun logs -L -f; then
  echo -e "\n$cross ERROR: Failed to get the pipelinerun logs successfully"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Wait for upto 5 minutes for the pipelinerun for the simluator app to complete
time=0
while [ "$(oc get pipelinerun -n $namespace $(oc get pipelinerun -n $namespace | grep $PIPELINERUN_UID | awk '{print $1}') -o json | jq -r '.status.conditions[0].status')" != "True" ]; do
  if [ $time -gt 5 ]; then
    echo -e "$cross ERROR: Timed out waiting for the pipelinerun for the quote lifecycle simulator app to succeed"
    exit 1
  fi

  if [ "$(oc get pipelinerun -n $namespace $(oc get pipelinerun -n $namespace | grep $PIPELINERUN_UID | awk '{print $1}') -o json | jq -r '.status.conditions[0].status')" == "False" ]; then
    echo -e "$cross ERROR: The pipelinerun for the quote lifecycle simulator app has failed\n"
    oc get pipelinerun $(oc get pipelinerun -n $namespace | grep $PIPELINERUN_UID | awk '{print $1}')
    exit 1
  fi

  echo -e "\nINFO: Waiting up to 5 minutes for the pipelinerun for the quote lifecycle simulator app to finish. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
done

echo -e "\n$tick INFO: The pipelinerun for the quote lifecycle simulator app has completed successfully, going ahead to delete the pipelinerun for it to delete the pods and the pvc\n"
oc get pipelinerun -n $namespace $(oc get pipelinerun -n $namespace | grep $PIPELINERUN_UID | awk '{print $1}')

echo -e "\n$tick INFO: The quote lifecycle simulator application has been deployed, but with zero replicas. To scale up the pods, run the command 'kubectl scale --replicas=<expected_replica_num> deployment simulator-eei'\n"
oc get deployment -n $namespace $(oc get deployments -n $namespace | grep simulator | awk '{print $1}')

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

if oc delete pipelinerun -n $namespace $(oc get pipelinerun -n $namespace | grep $PIPELINERUN_UID | awk '{print $1}'); then
  echo -e "$tick INFO: Deleted the pipelinerun with the uid '$PIPELINERUN_UID'"
else
  echo -e "$cross ERROR: Failed to delete the pipelinerun with the uid '$PIPELINERUN_UID'"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

if oc delete pvc git-workspace-eei -n $namespace; then
  echo -e "$tick INFO: Deleted the pvc 'git-workspace-eei'"
else
  echo -e "$cross ERROR: Failed to delete the pvc 'git-workspace-eei'"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
