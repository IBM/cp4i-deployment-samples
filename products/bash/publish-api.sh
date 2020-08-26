#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -e : <environment> (string), can be either "dev" or "test", defaults to "dev"
#   -n : <namespace> (string), defaults to "cp4i"
#   -r : <release> (string), defaults to "ademo"
#
# USAGE:
#   With default values
#     ./publish-api.sh
#   Overriding environment, namespace, and release name
#     ./publish-api.sh -e test -n namespace -r release
#******************************************************************************

# error handling with status codes
# we need to have the yamls in the repo so we should be calling it from the repo,
# therefore we might need sed to do replacements in the yaml as the yamls need to be configurable

function usage {
  echo "Usage: $0 -e <environment> -n <namespace> -r <release>"
}

CURRENT_DIR=$(dirname $0)

TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ENVIRONMENT="dev"
NAMESPACE="cp4i"
RELEASE="ademo"
DEV_ORG="main-demo"
TEST_ORG="ddd-demo-test"
CATALOG="$([[ $ENVIRONMENT == dev ]] && echo $DEV_ORG || echo $TEST_ORG)-catalog"
ACE_SECRET="ace-v11-service-creds"
APIC_SECRET="cp4i-admin-creds"

while getopts "e:n:r:" opt; do
  case ${opt} in
    e ) ENVIRONMENT="$OPTARG"
      ;;
    n ) NAMESPACE="$OPTARG"
      ;;
    r ) RELEASE="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

# install jq
echo -e "[DEBUG] Checking if jq is present..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  echo "[DEBUG] jq not found, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "[DEBUG] Installing on linux"
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    JQ=./jq
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "[DEBUG] Installing on macOS"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
  fi
fi

echo -e "[INFO] jq version: $($JQ --version)"

# gather info from cluster resources
echo "[INFO] Gathering cluster info..."
PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
API_MANAGER_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-api-manager -o jsonpath="{.spec.host}")
echo "[DEBUG] API_MANAGER_EP=${API_MANAGER_EP}"
APIC_CREDENTIALS=$(kubectl get secret $APIC_SECRET -n $NAMESPACE -o json | $JQ .data)
echo "[DEBUG] APIC_CREDENTIALS=${APIC_CREDENTIALS}"
API_MANAGER_USER=$(echo $APIC_CREDENTIALS | $JQ -r .username | base64 --decode)
echo "[DEBUG] API_MANAGER_USER=${API_MANAGER_USER}"
API_MANAGER_PASS=$(echo $APIC_CREDENTIALS | $JQ -r .password | base64 --decode)
echo "[DEBUG] API_MANAGER_PASS=${API_MANAGER_PASS}"
ACE_CREDENTIALS=$(kubectl get secret $ACE_SECRET -n $NAMESPACE -o json | $JQ .data)
echo "[DEBUG] ACE_CREDENTIALS=${ACE_CREDENTIALS}"
ACE_CLIENT_ID=$(echo $ACE_CREDENTIALS | $JQ -r .client_id | base64 --decode)
echo "[DEBUG] ACE_CLIENT_ID=${ACE_CLIENT_ID}"
ACE_CLIENT_SECRET=$(echo $ACE_CREDENTIALS | $JQ -r .client_secret | base64 --decode)
echo "[DEBUG] ACE_CLIENT_SECRET=${ACE_CLIENT_SECRET}"

function handle_res {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  echo "[DEBUG] ${body}"
  echo "[DEBUG] ${status}"
  if [[ $status == "null" ]]; then
    echo "${body}"
  else
    exit 1
  fi
}

# grab bearer token
echo "[INFO] Getting bearer token..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/token \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  -d "{
  \"username\": \"${API_MANAGER_USER}\",
  \"password\": \"${API_MANAGER_PASS}\",
  \"realm\": \"provider/default-idp-2\",
  \"client_id\": \"${ACE_CLIENT_ID}\",
  \"client_secret\": \"${ACE_CLIENT_SECRET}\",
  \"grant_type\": \"password\"
}")
TOKEN=$(handle_res "${RES}" | $JQ -r ".access_token")
echo "[DEBUG] Bearer token: ${TOKEN}"

declare -a ORGS=("${DEV_ORG}" "${TEST_ORG}")

for ORG in "${ORGS[@]}"; do
  # get org id
  echo "[INFO] Getting id for org '${ORG}'..."
  RES=$(curl -kLsS https://$API_MANAGER_EP/api/orgs/$ORG \
    -H "accept: application/yaml" \
    -H "authorization: Bearer ${TOKEN}" | $JQ -r ".id")
  ORG_ID=$(handle_res "${RES}")
  echo "[DEBUG] Org id: ${ORG_ID}"

  # create draft product
  echo "[DEBUG] Creating draft product in org '${ORG}'..."
  RES=$(curl -kLsS https://$API_MANAGER_EP/api/orgs/$ORG_ID/drafts/draft-products \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}" \
    -H "content-type: multipart/form-data" \
    -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-product-ddd.yaml;type=application/yaml" \
    -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-api-ddd.yaml;type=application/yaml")
  handle_res "${RES}"
done

# get catalog id
echo "[DEBUG] Getting catalog id..."
RES=$(curl -kLsS https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG \
  -H "accept: application/json" \
  -H "authorization: ${TOKEN}" | $JQ -r ".id")
CATALOG_ID=$(handle_res "${RES}")
echo "[DEBUG] Catalog id: ${CATALOG_ID}"

# publish product
echo "[DEBUG] Publishing product..."
RES=$(curl -kLsS https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG_ID/publish \
  -H "accept: application/json" \
  -H "authorization: bearer ${TOKEN}" \
  -H "content-type: multipart/form-data" \
  -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-product-ddd.yaml;type=application/yaml" \
  -F "openapi=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-api-ddd.yaml;type=application/yaml")
handle_res "${RES}"
echo "[DEBUG] Product published"
