#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

set -e

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -c <CERTIFICATE_NAME> -o <CONFIGURATION_NAME>"
  divider
  exit 1
}

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
NAMESPACE="cp4i"
CERTIFICATE_NAME="qm-mq-ddd-qm-dev-client"
CONFIGURATION_NAME="application-ddd-dev"

while getopts "c:n:o:" opt; do
  case ${opt} in
  c)
    CERTIFICATE_NAME="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  o)
    CONFIGURATION_NAME="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done



# Wait for the certificate to be ready, so the secret is ready to be used
oc wait --for=condition=ready certificate ${CERTIFICATE_NAME} --timeout=60s

# Create a move to a temporary dir
tmp=$(mktemp -d)
mkdir -p ${tmp}/mq-certs
cd ${tmp}/mq-certs

echo "Get the files out of the ${CERTIFICATE_NAME} certificate's secret"
CLIENT_CERTIFICATE_SECRET=$(oc get certificate $CERTIFICATE_NAME -o json | jq -r .spec.secretName)
echo "CLIENT_CERTIFICATE_SECRET=${CLIENT_CERTIFICATE_SECRET}"
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > ca.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > tls.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > tls.key

echo "Create a pem with the ca and cert"
cat ca.crt > application.pem
cat tls.crt >> application.pem

echo "Export the pem to a p12"
openssl pkcs12 -export -out mq-certs/application.p12 -inkey mq-certs/tls.key -in mq-certs/application.pem -passout pass:password

echo "Create the .kdb with the ca.crt and labelled application.p12"
runmqckm -keydb -create -db application.kdb -pw password -type cms -stash
runmqckm -cert -add -db application.kdb -file ca.crt -stashed
runmqckm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient

echo "Tidy up the intermediate files, only want .kdb and .sth"
rm ca.crt tls.crt tls.key application.pem application.p12 application.rdb
ls -al

echo "TODO Create the configuration"
cd $tmp

zip application.zip mq-certs/*

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo -e "$INFO [INFO] Creating ace config - base64 command for linux"
  CONTENTS="$(base64 -w0 application.zip)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "$INFO [INFO] Creating ace config base64 command for MAC"
  CONTENTS="$(base64 application.zip)"
fi

YAML=$(cat <<EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ${CONFIGURATION_NAME}
  namespace: ${NAMESPACE}
spec:
  type: generic
  contents: ${CONTENTS}
EOF
)
OCApplyYAML "$NAMESPACE" "$YAML"
echo -e "\n$TICK [SUCCESS] Successfully applied the configuration yaml"
