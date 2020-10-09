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
#   -g : <POSTGRES_NAMESPACE> psql namespace defaults to 'postgres'
#   -u : <DB_USER> (string), psql db user defaults to 'cp4i'
#   -d : <DB_NAME> (string), psql db name defaults to 'db_cp4i'
#   -p : <DB_PASS> (string), psql db password defaults to ''
#   -s : <SUFFIX> (string), project suffix defaults to 'ddd'
#
#   With defaults values
#     ./create-ace-config.sh
#
#   With overridden values
#     ./create-ace-config.sh -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -s <SUFFIX>

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
NAMESPACE="cp4i"
POSTGRES_NAMESPACE="postgres"
DB_USER="cp4i"
DB_NAME="db_cp4i"
DB_PASS=""
SUFFIX="ddd"
CURRENT_DIR=$(dirname $0)
CONFIG_DIR=$CURRENT_DIR/ace
CONFIG_YAML=$CONFIG_DIR/configurations.yaml
MQ_CERT=$CURRENT_DIR/mq/createcerts
API_USER="bruce"
API_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 ; echo)
KEYSTORE_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 ; echo)

function usage {
  echo "Usage: $0 -n <NAMESPACE> -g <POSTGRES_NAMESPACE> -u <DB_USER> -d <DB_NAME> -p <DB_PASS> -s <SUFFIX>"
  exit 1
}

function buildConfigurationCR {
  local type=$1
  local name=$2
  local file=$3
  echo "apiVersion: appconnect.ibm.com/v1beta1" >> $CONFIG_YAML
  echo "kind: Configuration" >> $CONFIG_YAML
  echo "metadata:" >> $CONFIG_YAML
  echo "  name: $name" >> $CONFIG_YAML
  echo "  namespace: $NAMESPACE" >> $CONFIG_YAML
  echo "spec:" >> $CONFIG_YAML
  echo "  contents: $(base64 -w0 $file)" >> $CONFIG_YAML
  echo "  type: $type" >> $CONFIG_YAML
  echo "---" >> $CONFIG_YAML
}

while getopts "n:g:u:d:p:s:" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    g ) POSTGRES_NAMESPACE="$OPTARG"
      ;;
    u ) DB_USER="$OPTARG"
      ;;
    d ) DB_NAME="$OPTARG"
      ;;
    p ) DB_PASS="$OPTARG"
      ;;
    s ) SUFFIX="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo "[DEBUG] Current directory: $CURRENT_DIR"

if [[ $SUFFIX == "ddd" ]]; then
  TYPES=("serverconf"                   "keystore"                 "keystore"                    "keystore"                         "truststore"                   "policyproject"                           "setdbparms"               )
  FILES=("$CONFIG_DIR/server.conf.yaml" "$CONFIG_DIR/keystore.p12" "$MQ_CERT/application.kdb"    "$MQ_CERT/application.sth"          "$MQ_CERT/application.jks"    "$CONFIG_DIR/$SUFFIX/DefaultPolicies"     "$CONFIG_DIR/setdbparms.txt")
  NAMES=("ace-serverconf"               "ace-keystore"             "application.kdb"             "application.sth"                   "application.jks"             "ace-policyproject-$SUFFIX"               "ace-setdbparms")
else
  TYPES=("policyproject")
  FILES=("$CONFIG_DIR/$SUFFIX/DefaultPolicies")
  NAMES=("ace-policyproject-$SUFFIX")
fi

if [[ -z "${DB_PASS// }" || -z "${NAMESPACE// }" || -z "${DB_USER// }" || -z "${DB_NAME// }" || -z "${POSTGRES_NAMESPACE// }" || -z "${SUFFIX// }" ]]; then
  echo -e "$cross ERROR: Some mandatory parameters are empty"
  usage
fi

# Store ace api password in secret
cat << EOF | oc apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: ace-api-creds
  namespace: $NAMESPACE
stringData:
  user: $API_USER
  pass: $API_PASS
  auth: "$API_USER:$API_PASS"
type: Opaque
EOF

[[ -f $CONFIG_YAML ]] && echo "[INFO]  Removing existing configurations yaml" && rm -f $CONFIG_YAML

echo "[INFO]  Creating policyproject for ace in the '$NAMESPACE' namespace"

DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="postgresql.$POSTGRES_NAMESPACE.svc.cluster.local"

echo "[INFO]  Database user: '$DB_USER'"
echo "[INFO]  Database name: '$DB_NAME'"
echo "[INFO]  Postgres pod name in the '$POSTGRES_NAMESPACE' namespace: '$DB_POD'"
echo "[INFO]  Postgres svc name: '$DB_SVC'"

if [[ $SUFFIX == "ddd" ]]; then
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "[INFO]  Creating keystore"
  CERTS_KEY_BUNDLE=$CONFIG_DIR/certs-key.pem
  CERTS=$CONFIG_DIR/certs.pem
  KEY=$CONFIG_DIR/key.pem
  KEYSTORE=$CONFIG_DIR/keystore.p12
  oc get secret -n openshift-config-managed router-certs -o json | jq -r '.data | .[]' | base64 --decode > $CERTS_KEY_BUNDLE
  openssl crl2pkcs7 -nocrl -certfile $CERTS_KEY_BUNDLE | openssl pkcs7 -print_certs -out $CERTS
  openssl pkey -in $CERTS_KEY_BUNDLE -out $KEY
  openssl pkcs12 -export -out $KEYSTORE -inkey $KEY -in $CERTS -password pass:$KEYSTORE_PASS

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "[INFO]  Templating setdbparms.txt"
  cat $CONFIG_DIR/setdbparms.txt.template |
    sed "s#{{API_USER}}#$API_USER#g;" |
    sed "s#{{API_PASS}}#$API_PASS#g;" |
    sed "s#{{KEYSTORE_PASS}}#$KEYSTORE_PASS#g;" > $CONFIG_DIR/setdbparms.txt
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

[[ ! -d $CONFIG_DIR/$SUFFIX/DefaultPolicies ]] && mkdir -p $CONFIG_DIR/$SUFFIX/DefaultPolicies

echo "[INFO]  Templating postgresql policy"
cat $CONFIG_DIR/PostgresqlPolicy.policyxml.template |
  sed "s#{{DB_NAME}}#$DB_NAME#g;" |
  sed "s#{{DB_USER}}#$DB_USER#g;" |
  sed "s#{{DB_PASS}}#$DB_PASS#g;" |
  sed "s#{{DB_SVC}}#$DB_SVC#g;" > $CONFIG_DIR/$SUFFIX/DefaultPolicies/PostgresqlPolicy.policyxml

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Generate configuration yaml
echo "[INFO]  Generating configuration yaml"
for i in ${!NAMES[@]}; do
  file=${FILES[$i]}
  echo "target: $file"
  if [[ -d $file ]]; then
    python -m zipfile -c $file.zip $file/
    file=$file.zip
    echo "zipped: $file.zip"
  fi
  buildConfigurationCR ${TYPES[$i]} ${NAMES[$i]} $file
done
echo -e "[DEBUG] config yaml:\n$(cat -n $CONFIG_YAML)"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Apply configuration yaml
echo "[INFO]  Applying configuration yaml"
oc apply -f $CONFIG_YAML

# DEBUG: get configurations
echo "[DEBUG] Getting configurations"
for i in ${!NAMES[@]}; do
  echo "[DEBUG] ${NAMES[$i]}"
  oc get -n $NAMESPACE configuration ${NAMES[$i]} -o yaml
done
