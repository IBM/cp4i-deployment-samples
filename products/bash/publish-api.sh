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
#   -d : <debug> (string), defaults to false
#
# USAGE:
#   With default values
#     ./publish-api.sh
#   Overriding environment, namespace, and release name, and enabling debug output
#     ./publish-api.sh -e test -n namespace -r release -d
#******************************************************************************

# Flow:
# ↡ obtain bearer token
# ↡ obtain org id
# ↡ create draft product with api and plan
# ↡ obtain catalog id
# ↡ publish product to catalog

function usage {
  echo "Usage: $0 -e <environment> -n <namespace> -r <release> -d"
}

CURRENT_DIR=$(dirname $0)
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ENVIRONMENT="dev"
NAMESPACE="cp4i"
RELEASE="ademo"
DEBUG=false

while getopts "e:n:r:d" opt; do
  case ${opt} in
    e ) ENVIRONMENT="$OPTARG"
      ;;
    n ) NAMESPACE="$OPTARG"
      ;;
    r ) RELEASE="$OPTARG"
      ;;
    d ) DEBUG=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

ORG=$([[ $ENVIRONMENT == "dev" ]] && echo "main-demo" || echo "ddd-demo-test")
CATALOG="${ORG}-catalog"
ACE_SECRET="ace-v11-service-creds"
APIC_SECRET="cp4i-admin-creds"

# install jq
$DEBUG && echo "[DEBUG] Checking if jq is present..."
jqInstalled=false

if ! command -v jq &> /dev/null; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  $DEBUG && echo "[DEBUG] jq not found, installing jq..."
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

echo "[INFO] jq version: $($JQ --version)"

# gather info from cluster resources
printf "[INFO] Gathering cluster info..."
PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
API_MANAGER_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-api-manager -o jsonpath="{.spec.host}")
$DEBUG && echo "[DEBUG] API_MANAGER_EP=${API_MANAGER_EP}"
ACE_API_ROUTE=$(oc get routes | grep -i ace-api-int-srv-http-$NAMESPACE | awk '{print $2}')
$DEBUG && echo "[DEBUG] ACE_API_ROUTE=${ACE_API_ROUTE}"
APIC_CREDENTIALS=$(kubectl get secret $APIC_SECRET -n $NAMESPACE -o json | $JQ .data)
$DEBUG && echo "[DEBUG] APIC_CREDENTIALS=${APIC_CREDENTIALS}"
API_MANAGER_USER=$(echo $APIC_CREDENTIALS | $JQ -r .username | base64 --decode)
$DEBUG && echo "[DEBUG] API_MANAGER_USER=${API_MANAGER_USER}"
API_MANAGER_PASS=$(echo $APIC_CREDENTIALS | $JQ -r .password | base64 --decode)
$DEBUG && echo "[DEBUG] API_MANAGER_PASS=${API_MANAGER_PASS}"
ACE_CREDENTIALS=$(kubectl get secret $ACE_SECRET -n $NAMESPACE -o json | $JQ .data)
$DEBUG && echo "[DEBUG] ACE_CREDENTIALS=${ACE_CREDENTIALS}"
ACE_CLIENT_ID=$(echo $ACE_CREDENTIALS | $JQ -r .client_id | base64 --decode)
$DEBUG && echo "[DEBUG] ACE_CLIENT_ID=${ACE_CLIENT_ID}"
ACE_CLIENT_SECRET=$(echo $ACE_CREDENTIALS | $JQ -r .client_secret | base64 --decode)
$DEBUG && echo "[DEBUG] ACE_CLIENT_SECRET=${ACE_CLIENT_SECRET}"
echo "[INFO] ${TICK} Cluster info gathered"

OUTPUT=""
function handle_res {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "409" ]]; then
    OUTPUT="${body}"
    echo "[INFO] Resource already exists, continuing..."
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
handle_res "${RES}"
TOKEN=$(echo "${OUTPUT}" | $JQ -r ".access_token")
$DEBUG && echo "[DEBUG] Bearer token: ${TOKEN}"
echo "[INFO] ${TICK} Got bearer token"

# template api and product yamls
echo "[INFO] Templating api yaml..."
cat ${CURRENT_DIR}/../../DrivewayDentDeletion/Operators/apic-resources/apic-api-ddd.yaml |
  sed "s#{{ACE_API_INT_SRV_ROUTE}}#${ACE_API_ROUTE}#g;" > ${CURRENT_DIR}/api.yaml
$DEBUG && echo -e "[DEBUG] api yaml:\n$(cat ${CURRENT_DIR}/api.yaml)"
echo "[INFO] ${TICK} Templated api yaml"

echo "[INFO] Templating product yaml..."
cat ${CURRENT_DIR}/../../DrivewayDentDeletion/Operators/apic-resources/apic-product-ddd.yaml |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > ${CURRENT_DIR}/product.yaml
$DEBUG && echo -e "[DEBUG] product yaml:\n$(cat ${CURRENT_DIR}/product.yaml)"
echo "[INFO] ${TICK} Templated product yaml"

# get org id
echo "[INFO] Getting id for org '${ORG}'..."
RES=$(curl -kLsS https://$API_MANAGER_EP/api/orgs/$ORG \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
ORG_ID=$(echo "${OUTPUT}" | $JQ -r ".id")
$DEBUG && echo "[DEBUG] Org id: ${ORG_ID}"
echo "[INFO] ${TICK} Got id for org '${ORG}'"

# create draft product
echo "[INFO] Creating draft product in org '${ORG}'..."
RES=$(curl -kLsS -X POST https://$API_MANAGER_EP/api/orgs/$ORG_ID/drafts/draft-products \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: multipart/form-data" \
  -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
  -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
handle_res "${RES}"
echo "[INFO] ${TICK} Draft product created in org '${ORG}'"

if [[ $DEBUG == true ]]; then
  # get draft products
  echo "[DEBUG] Getting draft products..."
  RES=$(curl -kLsS https://$API_MANAGER_EP/api/orgs/${ORG_ID}/drafts/draft-products \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  echo -e "[DEBUG] ${TICK} Draft products:\n${OUTPUT}"
fi

# get catalog id
echo "[INFO] Getting id for catalog ${CATALOG}..."
RES=$(curl -kLsS https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
CATALOG_ID=$(echo "${OUTPUT}" | $JQ -r ".id")
$DEBUG && echo "[DEBUG] Catalog id: ${CATALOG_ID}"
echo "[INFO] ${TICK} Got id for catalog ${CATALOG}"

# publish product
echo "[INFO] Publishing product..."
RES=$(curl -kLsS -X POST https://$API_MANAGER_EP/api/catalogs/$ORG_ID/$CATALOG_ID/publish \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: multipart/form-data" \
  -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
  -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
handle_res "${RES}"
echo "[INFO] ${TICK} Product published"
