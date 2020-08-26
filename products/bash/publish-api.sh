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

# gather info from cluster resources
PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
API_MANAGER_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-api-manager -o jsonpath="{.spec.host}")
APIC_CREDENTIALS=$(kubectl get secret $APIC_SECRET -n $NAMESPACE -o json | jq .data)
API_MANAGER_USER=$(echo $APIC_CREDENTIALS | jq -r .username | base64 --decode)
API_MANAGER_PASS=$(echo $APIC_CREDENTIALS | jq -r .password | base64 --decode)
ACE_CREDENTIALS=$(kubectl get secret $ACE_SECRET -n $NAMESPACE -o json | jq .data)
ACE_CLIENT_ID=$(echo $ACE_CREDENTIALS | jq -r .client_id | base64 --decode)
ACE_CLIENT_SECRET=$(echo $ACE_CREDENTIALS | jq -r .client_secret | base64 --decode)

# ----------------------------------------------- INSTALL JQ --------------------------------------------------------- #

echo "INFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
else
  jqInstalled=true
fi

if [[ "$jqInstalled" == "false" ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
fi

echo -e "\nINFO: Installed JQ version is $(./jq --version)"

function handle_res {
  local body=$1
  local status=$(echo ${body} | jq -r .status)
  if [[ $status == "null" ]]; then
    echo "${body}"
  else
    exit 1
  fi
}

# grab bearer token
RES=$(curl -kLsS -w "%{http_code}\n" -X POST \
  https://$PLATFORM_API_EP/api/token \
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
TOKEN=$(handle_res "${RES}")

declare -a ORGS=("${DEV_ORG}" "${TEST_ORG}")

for ORG in "${ORGS[@]}"; do
  # get org id
  RES=$(curl -kLsS -w "%{http_code}\n" \
    https://$API_MANAGER_EP/api/orgs/$ORG \
    -H "accept: application/yaml" \
    -H "authorization: Bearer ${TOKEN}" | ./jq -r .id)
  ORG_ID=$(handle_res "${RES}")

  # create draft product
  RES=$(curl -kLsS -w "%{http_code}\n" -X POST
    https://$API_MANAGER_EP/api/orgs/$ORG_ID/drafts/draft-products \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}" \
    -H "content-type: multipart/form-data" \
    -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-product-ddd.yaml;type=application/yaml" \
    -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-api-ddd.yaml;type=application/yaml")
  handle_res "${RES}"
done

# get catalog id
RES=$(curl -kLsS -w "%{http_code}\n" \
  https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG \
  -H "accept: application/json" \
  -H "authorization: ${TOKEN}" | ./jq -r .id)
CATALOG_ID=$(handle_res "${RES}")

# publish product
RES=$(curl -kLsS -w "%{http_code}\n" -X POST \
  https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG_ID/publish \
  -H "accept: application/json" \
  -H "authorization: bearer ${TOKEN}" \
  -H "content-type: multipart/form-data" \
  -F "product=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-product-ddd.yaml;type=application/yaml" \
  -F "openapi=@${CURRENT_DIR}/../DrivewayDentDeletion/Operators/test-api-ddd.yaml;type=application/yaml")
handle_res "${RES}"
