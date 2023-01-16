#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PARAMETERS:
#   -n : <NAMESPACE> (string), namespace defaults to 'cp4i'
#   -g : <POSTGRES_NAMESPACE> psql namespace defaults to the value of <NAMESPACE>
#   -u : <DB_USER> (string), psql db user defaults to 'cp4i'
#   -d : <DB_NAME> (string), psql db name defaults to 'db_cp4i'
#   -p : <DB_PASS> (string), psql db password defaults to ''
#   -s : <SUFFIX> (string), project suffix defaults to 'ddd'
#   -t : <DDD_DEMO_TYPE> (string), demo type defaults to 'dev' for driveway dent deletion demo, optional
#
#   With defaults values
#     ./create-ace-config.sh
#
#   With overridden values
#     ./create-ace-config.sh -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -s <SUFFIX> -t

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -s <SUFFIX> [-t]"
  divider
  exit 1
}

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
DDD_DEMO_TYPE="dev"
MISSING_PARAMS="false"
NAMESPACE="cp4i"
POSTGRES_NAMESPACE=
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
SUFFIX="ddd"
WORKING_DIR=/tmp
CONFIG_DIR=$WORKING_DIR/ace
CONFIG_YAML=$WORKING_DIR/configurations.yaml
API_USER="bruce"
KEYSTORE_PASS=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
  echo
)
KEYSTORE=$WORKING_DIR/keystore.p12

function buildConfigurationCR() {
  local type=$1
  local name=$2
  local file=$3
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "$INFO [INFO] Creating ace config - base64 command for linux"
    COMMAND="base64 -w0 $file"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "$INFO [INFO] Creating ace config base64 command for MAC"
    COMMAND="base64 -i $file"
  fi
  CONTENTS="$($COMMAND)"
  if [[ "$?" != "0" ]]; then
    echo -e "$CROSS [ERROR] Failed to base64 encode file using: $COMMAND"
    exit 1
  fi

  echo "apiVersion: appconnect.ibm.com/v1beta1" >>$CONFIG_YAML
  echo "kind: Configuration" >>$CONFIG_YAML
  echo "metadata:" >>$CONFIG_YAML
  echo "  name: $name" >>$CONFIG_YAML
  echo "  namespace: $NAMESPACE" >>$CONFIG_YAML
  echo "spec:" >>$CONFIG_YAML
  echo "  contents: ${CONTENTS}" >>$CONFIG_YAML
  echo "  type: $type" >>$CONFIG_YAML
  echo "---" >>$CONFIG_YAML
}

while getopts "n:g:u:d:p:s:t" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  g)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  u)
    DB_USER="$OPTARG"
    ;;
  d)
    DB_NAME="$OPTARG"
    ;;
  p)
    DB_PASS="$OPTARG"
    ;;
  s)
    SUFFIX="$OPTARG"
    ;;
  t)
    DDD_DEMO_TYPE="test"
    ;;
  \?)
    usage
    ;;
  esac
done

POSTGRES_NAMESPACE=${POSTGRES_NAMESPACE:-$NAMESPACE}

if [[ -z "${NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace parameter is empty. Please provide a value for '-n' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${POSTGRES_NAMESPACE// /}" ]]; then
  echo -e "$CROSS [ERROR] Namespace parameter is empty. Please provide a value for '-g' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DB_NAME// /}" ]]; then
  echo -e "$CROSS [ERROR] Database name of the postgres parameter is empty. Please provide a value for '-d' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DB_USER// /}" ]]; then
  echo -e "$CROSS [ERROR] Database username for postgres parameter is empty. Please provide a value for '-u' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${DB_PASS// /}" ]]; then
  echo -e "$CROSS [ERROR] Database password for postgres parameter is empty. Please provide a value for '-p' parameter."
  MISSING_PARAMS="true"
fi

if [[ -z "${SUFFIX// /}" ]]; then
  echo -e "$CROSS [ERROR] Suffix parameter is empty. Please provide a value for '-s' parameter."
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  usage
fi

if [[ -z "$DEBUG" ]]; then
  DEBUG="false"
fi

DDD_DEV_TEST_SUFFIX=$([[ $SUFFIX == "ddd" ]] && echo "-${DDD_DEMO_TYPE}" || echo "")

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"

echo -e "$INFO [INFO] Current directory: $CURRENT_DIR"
echo -e "$INFO [INFO] Working directory: $WORKING_DIR"
echo -e "$INFO [INFO] Config directory: $CONFIG_DIR"
echo -e "$INFO [INFO] Namespace passed: '$NAMESPACE'"
echo -e "$INFO [INFO] Namespace passed for postgres: '$POSTGRES_NAMESPACE'"
echo -e "$INFO [INFO] Demo suffix passed for postgres: '$SUFFIX'"
[[ $SUFFIX == "ddd" ]] && echo -e "$INFO [INFO] Demo type for driveway dent deletion demo: '$DDD_DEMO_TYPE'" && echo -e "$INFO [INFO] Suffix for ace policyproject name for driveway dent deletion demo: '$DDD_DEV_TEST_SUFFIX'"
echo -e "$INFO [INFO] Database username: '$DB_USER'"
echo -e "$INFO [INFO] Database name: '$DB_NAME'"
echo -e "$INFO [INFO] Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo -e "$INFO [INFO] Postgres svc name: '$DB_SVC'"
echo -e "$INFO [INFO] DEBUG mode in creating ace config: '$DEBUG'"

divider

TYPES=("serverconf" "keystore" "policyproject" "setdbparms")
FILES=("$CONFIG_DIR/$SUFFIX/server.conf.yaml" "$KEYSTORE" "$CONFIG_DIR/$SUFFIX/DefaultPolicies" "$CONFIG_DIR/$SUFFIX/setdbparms.txt")
NAMES=("serverconf-$SUFFIX" "keystore-$SUFFIX" "policyproject-${SUFFIX}${DDD_DEV_TEST_SUFFIX}" "setdbparms-$SUFFIX")

# Copy all static config files & templates to default working directory (/tmp)
cp -r $CURRENT_DIR/ace $CURRENT_DIR/mq-im $WORKING_DIR/
$DEBUG && divider && echo -e "[DEBUG] Listing /tmp:\n$(ls -lAFL /tmp)"

EXISTING_PASS=$(oc get secret ace-api-creds-$SUFFIX -ojsonpath='{.data.pass}' 2>/dev/null | base64 --decode)
if [[ -z $EXISTING_PASS ]]; then
  API_PASS=$(
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
    echo
  )
  # Store ace api password
  YAML=$(cat <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: ace-api-creds-$SUFFIX
  namespace: $NAMESPACE
stringData:
  user: $API_USER
  pass: $API_PASS
  auth: "$API_USER:$API_PASS"
type: Opaque
EOF
)
  OCApplyYAML "$NAMESPACE" "$YAML"

  if [[ "$?" != "0" ]]; then
    echo -e "$CROSS [ERROR] Failed to create 'ace-api-creds-$SUFFIX' secret in '$NAMESPACE' namespace"
    exit 1
  fi
else
  API_PASS=$EXISTING_PASS
fi

divider && [[ -f $CONFIG_YAML ]] && echo -e "$INFO [INFO] Removing existing configurations yaml" && rm -f $CONFIG_YAML && divider

echo -e "$INFO [INFO] Creating policyproject for ace in the '$NAMESPACE' namespace\n"

echo -e "$INFO [INFO] Creating keystore"
CERTS_KEY_BUNDLE=$CONFIG_DIR/certs-key.pem
CERTS=$CONFIG_DIR/certs.pem
KEY=$CONFIG_DIR/key.pem
rm $CERTS $KEY $KEYSTORE
oc -n openshift-config-managed get secret router-certs -o json | jq -r '.data | .[]' | base64 --decode >$CERTS_KEY_BUNDLE
openssl crl2pkcs7 -nocrl -certfile $CERTS_KEY_BUNDLE | openssl pkcs7 -print_certs -out $CERTS
openssl pkey -in $CERTS_KEY_BUNDLE -out $KEY
openssl pkcs12 -export -out $KEYSTORE -inkey $KEY -in $CERTS -password pass:$KEYSTORE_PASS

divider

echo -e "$INFO [INFO] Templating server.conf.yaml"
cat $CONFIG_DIR/server.conf.yaml.template |
  sed "s#{{KEYSTORE}}#keystore-$SUFFIX#g;" >$CONFIG_DIR/$SUFFIX/server.conf.yaml

divider

echo -e "$INFO [INFO] Templating setdbparms.txt"
cat $CONFIG_DIR/setdbparms.txt.template |
  sed "s#{{API_USER}}#$API_USER#g;" |
  sed "s#{{API_PASS}}#$API_PASS#g;" |
  sed "s#{{KEYSTORE_PASS}}#$KEYSTORE_PASS#g;" >$CONFIG_DIR/$SUFFIX/setdbparms.txt

divider

[[ ! -d $CONFIG_DIR/$SUFFIX/DefaultPolicies ]] && mkdir -p $CONFIG_DIR/$SUFFIX/DefaultPolicies

echo -e "$INFO [INFO] Templating postgresql policy"
cat $CONFIG_DIR/PostgresqlPolicy.policyxml.template |
  sed "s#{{DB_SVC}}#$DB_SVC#g;" |
  sed "s#{{DB_NAME}}#$DB_NAME#g;" |
  sed "s#{{DB_USER}}#$DB_USER#g;" |
  sed "s#{{DB_PASS}}#$DB_PASS#g;" >$CONFIG_DIR/$SUFFIX/DefaultPolicies/PostgresqlPolicy.policyxml

divider

echo -e "$INFO [INFO] Templating mq policy"
if [[ $SUFFIX == "ddd" ]]; then
  QM_NAME=mqdddqm${DDD_DEMO_TYPE}
  QM_HOST="mq-ddd-qm-${DDD_DEMO_TYPE}-ibm-mq"
else
  QM_NAME=mqeeiqm
  QM_HOST="mq-eei-qm-ibm-mq"
fi
QM_CHANNEL="MTLS.SVRCONN"
cat $CONFIG_DIR/MQEndpointPolicy.policyxml.template |
  sed "s#ACE_SVRCONN#$QM_CHANNEL#g;" |
  sed "s#{{QM_NAME}}#$QM_NAME#g;" |
  sed "s#{{QM_HOST}}#$QM_HOST#g;" >$CONFIG_DIR/$SUFFIX/DefaultPolicies/MQEndpointPolicy.policyxml

divider

# Generate configuration yaml
echo -e "$INFO [INFO] Generating configuration yaml"
for i in ${!NAMES[@]}; do
  file=${FILES[$i]}
  echo -e "\n$INFO [INFO] Target: $file"
  if [[ -d $file ]]; then
    python -m zipfile -c $file.zip $file/
    if [[ "$?" != "0" ]]; then
      echo -e "$CROSS [ERROR] Failed to zip dir using python"
      exit 1
    fi

    file=$file.zip
    echo -e "\n$INFO [INFO] Zipped: $file.zip"
  fi
  buildConfigurationCR ${TYPES[$i]} ${NAMES[$i]} $file
done

$DEBUG && divider && echo -e "[DEBUG] config yaml:\n\n $(cat -n $CONFIG_YAML)"

divider

# Apply configuration yaml
echo -e "$INFO [INFO] Applying configuration yaml\n"
YAML=$(cat $CONFIG_YAML)
OCApplyYAML "$NAMESPACE" "$YAML"
echo -e "\n$TICK [SUCCESS] Successfully applied all the configuration yaml"


echo -e "$INFO [INFO] Creating barauth-empty to allow pulling bar files from urls that don't require auth\n"
YAML=$(cat <<EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: barauth-empty
spec:
  type: barauth
  description: Authentication for public GitHub, no credentials needed
  data: $(echo '{"authType":"BASIC_AUTH","credentials":{"username":"","password":""}}' | base64)
EOF
)
OCApplyYAML "$NAMESPACE" "$YAML"

# DEBUG: get configurations
$DEBUG && divider && echo "[DEBUG] Getting configurations"
for i in ${!NAMES[@]}; do
  $DEBUG && echo "[DEBUG] ${NAMES[$i]}"
  $DEBUG && oc get -n $NAMESPACE configuration ${NAMES[$i]} -o yaml
done

divider
