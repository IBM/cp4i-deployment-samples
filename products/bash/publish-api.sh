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

# Flow:
# ↡ obtain bearer token
# ↡ generate api and product yamls from template
# ↡ obtain org id
# ↡ obtain catalog id
# ↡ store values in configmap
# ↡ publish product to catalog

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

ORG=$([[ $ENVIRONMENT == "dev" ]] && echo "main-demo" || echo "ddd-demo-test")
PRODUCT=${NAMESPACE}-product-ddd
CATALOG="$ORG-catalog"

# Install jq
$DEBUG && echo "[DEBUG] Checking if jq is present..."
jqInstalled=false

if ! command -v jq &> /dev/null; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  echo "[DEBUG] jq not found, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    $DEBUG && printf "on linux..."
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    JQ=./jq
    $DEBUG && echo "[DEBUG] ${TICK} jq installed"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    $DEBUG && printf "on macOS..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
    $DEBUG && echo "[DEBUG] ${TICK} jq installed"
  fi
fi

echo "[INFO]  jq version: $($JQ --version)"

# Gather info from cluster resources
echo "[INFO]  Gathering cluster info..."
PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
API_MANAGER_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-api-manager -o jsonpath="{.spec.host}")
$DEBUG && echo "[DEBUG] API_MANAGER_EP=${API_MANAGER_EP}"
ACE_API_ROUTE=$(oc get routes | grep -i ace-api-int-srv-http-$NAMESPACE | awk '{print $2}')
$DEBUG && echo "[DEBUG] ACE_API_ROUTE=${ACE_API_ROUTE}"
echo -e "[INFO]  ${TICK} Cluster info gathered"

function handle_res {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  echo "[DEBUG] ${body}"
  echo "[DEBUG] ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "409" ]]; then
    OUTPUT="${body}"
    echo "[INFO]  Resource already exists, continuing..."
  else
    echo -e "[ERROR] ${CROSS} Computer says no..."
    exit 1
  fi
}

# Grab bearer token
echo "[INFO]  Getting bearer token..."
TOKEN=$(${CURRENT_DIR}/get-apic-token.sh -n $NAMESPACE -r $RELEASE)
$DEBUG && echo "[DEBUG] Bearer token: ${TOKEN}"
echo -e "[INFO]  ${TICK} Got bearer token"

# Template api and product yamls
echo "[INFO]  Templating api yaml..."
cat ${CURRENT_DIR}/../../DrivewayDentDeletion/Operators/apic-resources/apic-api-ddd.yaml |
  sed "s#{{ACE_API_INT_SRV_ROUTE}}#${ACE_API_ROUTE}#g;" > ${CURRENT_DIR}/api.yaml
$DEBUG && echo -e "[DEBUG] api yaml:\n$(cat ${CURRENT_DIR}/api.yaml)"
echo -e "[INFO]  ${TICK} Templated api yaml"

echo "[INFO]  Templating product yaml..."
cat ${CURRENT_DIR}/../../DrivewayDentDeletion/Operators/apic-resources/apic-product-ddd.yaml |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > ${CURRENT_DIR}/product.yaml
$DEBUG && echo -e "[DEBUG] product yaml:\n$(cat ${CURRENT_DIR}/product.yaml)"
echo -e "[INFO]  ${TICK} Templated product yaml"

# Get org id
echo "[INFO]  Getting id for org '$ORG'..."
ORG_ID=$(oc get -n $NAMESPACE configmap ${ORG}-info -o jsonpath="{.data.ORG_ID}")
$DEBUG && echo "[DEBUG] Org id: $ORG_ID"
echo -e "[INFO]  ${TICK} Got id for org '$ORG'"

# Get catalog id
echo "[INFO]  Getting id for catalog ${CATALOG}..."
CATALOG_ID=$(oc get -n $NAMESPACE configmap ${ORG}-info -o jsonpath="{.data.CATALOG_ID}")
$DEBUG && echo "[DEBUG] Catalog id: ${CATALOG_ID}"
echo -e "[INFO]  ${TICK} Got id for catalog ${CATALOG}"

# Run some tests

# Publish product
echo "[INFO]  Publishing product..."
RES=$(curl -kLsS -X POST https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG_ID/publish \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: multipart/form-data" \
  -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
  -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
handle_res "${RES}"
echo -e "[INFO]  ${TICK} Product published"
