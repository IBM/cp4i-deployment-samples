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
#   -e : <ENVIRONMENT> (string), can be either "dev" or "test", defaults to "dev". "test" currently only suitable for DDD.
#   -n : <NAMESPACE> (string), defaults to "cp4i"
#   -r : <RELEASE> (string), defaults to "ademo"
#   -d : <DEMO_NAME> (string), default to "ddd".
#   -t : <TARGET_URL> (string), default to "". If "" then constructs the URL to point to the ace-api-int-srv-is service
#   -p : <PRODUCT_YAML_TEMPLATE> (string), Path relative to root of the repo, defaults to "DrivewayDentDeletion/Operators/apic-resources/apic-product-ddd.yaml"
#   -s : <SWAGGER_YAML_TEMPLATE> (string), Path relative to root of the repo, defaults to "DrivewayDentDeletion/Operators/apic-resources/apic-api-ddd.yaml"
#
# USAGE:
#   With default values
#     ./pub-sub-apic.sh
#   Overriding environment, namespace, and release name, and enabling debug output
#     ./pub-sub-apic.sh -e test -n namespace -r release -d
#******************************************************************************

# Flow:
# ↡ obtain bearer token
# ↡ generate api and product yamls from template
# ↡ obtain org id
# ↡ obtain catalog id
# ↡ store values in configmap
# ↡ publish product to catalog

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
DEMO_NAME="ddd"
TARGET_URL=""
PRODUCT_YAML_TEMPLATE="DrivewayDentDeletion/Operators/apic-resources/apic-product-ddd.yaml"
SWAGGER_YAML_TEMPLATE="DrivewayDentDeletion/Operators/apic-resources/apic-api-ddd.yaml"
# TODO
DEBUG=true

function usage() {
  echo "Usage: $0 -e <ENVIRONMENT> -n <MAIN_NAMESPACE> -r <RELEASE> -d <DEMO_NAME> -t <TARGET_URL> -p <PRODUCT_YAML_TEMPLATE> -s <SWAGGER_YAML_TEMPLATE>"
}

while getopts "e:n:r:d:t:p:s:" opt; do
  case ${opt} in
  e)
    ENVIRONMENT="$OPTARG"
    ;;
  n)
    MAIN_NAMESPACE="$OPTARG"
    ;;
  r)
    RELEASE="$OPTARG"
    ;;
  d)
    DEMO_NAME="$OPTARG"
    ;;
  t)
    TARGET_URL="$OPTARG"
    ;;
  p)
    PRODUCT_YAML_TEMPLATE="$OPTARG"
    ;;
  s)
    SWAGGER_YAML_TEMPLATE="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

OUTPUT=""
function handle_res() {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "400" ]]; then
    if [[ $body == *"already exists"* || $body == *"already subscribed"* ]]; then
      OUTPUT="${body}"
      echo "[INFO]  Resource already exists, continuing..."
    else
      echo -e "[ERROR] ${CROSS} Got 400 bad request"
      exit 1
    fi
  elif [[ $status == "409" ]]; then
    OUTPUT="${body}"
    echo "[INFO]  Resource already exists, continuing..."
  else
    echo -e "[ERROR] ${CROSS} Request failed: ${body}..."
    exit 1
  fi
}

NAMESPACE=$MAIN_NAMESPACE
ORG=$([[ $ENVIRONMENT == "dev" ]] && echo "main-demo" || echo "ddd-demo-test")
CATALOG=${ORG}-catalog
PRODUCT=${NAMESPACE}-product-${DEMO_NAME}
C_ORG=${ORG}-corp
APP=${DEMO_NAME}-app

# Gather info from cluster resources
echo "[INFO]  Gathering cluster info..."
APIC_NAMESPACE=${MAIN_NAMESPACE}
$DEBUG && echo "[DEBUG] $APIC_NAMESPACE"
$DEBUG && echo "[DEBUG] $NAMESPACE"
PLATFORM_API_EP=$(oc get route -n $APIC_NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
[[ -z $PLATFORM_API_EP ]] && echo -e "[ERROR] ${CROSS} APIC platform api route doesn't exit" && exit 1
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"

# Install jq
$DEBUG && echo "[DEBUG] Checking if jq is present..."
jqInstalled=false

if ! command -v jq &>/dev/null; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  echo "[DEBUG] jq not found, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    $DEBUG && printf "on linux..."
    wget --quiet -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
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

if [[ -z $TARGET_URL ]]; then
  ACE_API="ddd-${ENVIRONMENT}-ace-api-is"
  ACE_API_INT_SRV_PORT=$(oc get svc -n $NAMESPACE ${ACE_API} -ojson | $JQ -r '.spec.ports[] | select(.name == "https").port')
  TARGET_URL="https://${ACE_API}.${NAMESPACE}.svc.cluster.local:$ACE_API_INT_SRV_PORT"
fi

ACE_API_USER=$(oc get secret -n $NAMESPACE ace-api-creds-${DEMO_NAME} -o json | $JQ -r '.data.user' | base64 --decode)
ACE_API_PASS=$(oc get secret -n $NAMESPACE ace-api-creds-${DEMO_NAME} -o json | $JQ -r '.data.pass' | base64 --decode)
$DEBUG && echo "[DEBUG] TARGET_URL=${TARGET_URL}"
echo -e "[INFO]  ${TICK} Cluster info gathered"

# Grab bearer token
echo "[INFO]  Getting bearer token..."
TOKEN=$(${CURRENT_DIR}/get-apic-token.sh -n $MAIN_NAMESPACE -r $RELEASE)
$DEBUG && echo "[DEBUG] Bearer token: ${TOKEN}"
echo -e "[INFO]  ${TICK} Got bearer token"

# Template api and product yamls
echo "[INFO]  Templating api yaml..."
cat ${CURRENT_DIR}/../../${SWAGGER_YAML_TEMPLATE} |
  sed "s#{{TARGET_URL}}#${TARGET_URL}#g;" |
  sed "s#{{BASIC_AUTH_USERNAME}}#${ACE_API_USER}#g;" |
  sed "s#{{BASIC_AUTH_PASSWORD}}#${ACE_API_PASS}#g;" >${CURRENT_DIR}/api.yaml
$DEBUG && echo -e "[DEBUG] api yaml:\n$(cat ${CURRENT_DIR}/api.yaml)"
echo -e "[INFO]  ${TICK} Templated api yaml"

echo "[INFO]  Templating product yaml..."
cat ${CURRENT_DIR}/../../${PRODUCT_YAML_TEMPLATE} |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" >${CURRENT_DIR}/product.yaml
$DEBUG && echo -e "[DEBUG] product yaml:\n$(cat ${CURRENT_DIR}/product.yaml)"
echo -e "[INFO]  ${TICK} Templated product yaml"

# Get product and api versions
API_VER=$(grep 'version:' ${CURRENT_DIR}/api.yaml | head -1 | awk '{print $2}')
PRODUCT_VER=$(grep 'version:' ${CURRENT_DIR}/product.yaml | head -1 | awk '{print $2}')

# Draft product first for dev, straight to publish for test
if [[ $ENVIRONMENT == "dev" ]]; then
  # Does product already exist
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/orgs/$ORG/drafts/draft-products \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  echo "[DEBUG] output: ${OUTPUT}"
  MATCHING_PRODUCT=$(echo ${OUTPUT} | $JQ -r '.results[] | select(.name == "'$PRODUCT'" and .version == "'$PRODUCT_VER'")')
  echo "[DEBUG] matching product: ${MATCHING_PRODUCT}"

  echo "[INFO] Checking for existing product..."
  if [[ ! $MATCHING_PRODUCT || $MATCHING_PRODUCT == "null" ]]; then
    # Create draft product
    echo "[INFO]  Creating draft product in org '$ORG'..."
    RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/orgs/$ORG/drafts/draft-products \
      -H "accept: application/json" \
      -H "authorization: Bearer ${TOKEN}" \
      -H "content-type: multipart/form-data" \
      -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
      -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
    handle_res "${RES}"
    echo -e "[INFO]  ${TICK} Draft product created in org '$ORG'"
  else
    # Replace draft product
    echo "[INFO]  Matching product found, replacing draft product in org '$ORG'..."
    RES=$(curl -kLsS -X PATCH https://$PLATFORM_API_EP/api/orgs/$ORG/drafts/draft-products/$PRODUCT/$PRODUCT_VER \
      -H "accept: application/json" \
      -H "authorization: Bearer ${TOKEN}" \
      -H "content-type: multipart/form-data" \
      -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
      -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
    handle_res "${RES}"
    echo -e "[INFO]  ${TICK} Draft product replaced in org '$ORG'"
  fi

  # Get product url
  echo "[DEBUG] Getting product url..."
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/orgs/$ORG/drafts/draft-products \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  $DEBUG && echo -e "PRODUCT='${PRODUCT}'\nPRODUCT_VER='${PRODUCT_VER}'\nOUTPUT=${OUTPUT}"
  DRAFT_PRODUCT_URL=$(echo ${OUTPUT} | $JQ -r '.results[] | select(.name == "'$PRODUCT'" and .version == "'$PRODUCT_VER'").url')
  if [[ $DRAFT_PRODUCT_URL == "null" ]] || [[ $DRAFT_PRODUCT_URL == "" ]]; then
    echo -e "[ERROR] ${CROSS} Couldn't get product url"
    exit 1
  fi
  $DEBUG && echo "[DEBUG] Product url: '${DRAFT_PRODUCT_URL}'"
  echo -e "[INFO]  ${TICK} Got product url"

  # Get gateway service url
  echo "[INFO]  Getting gateway service url..."
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/orgs/$ORG/gateway-services \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  GW_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].integration_url")
  $DEBUG && echo "[DEBUG] Gateway service url: ${GW_URL}"
  echo -e "[INFO]  ${TICK} Got gateway service url"

  # Stage draft product
  echo "[INFO]  Staging draft product..."
  RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/stage-draft-product \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}" \
    -H "content-type: application/json" \
    -d "{
    \"gateway_service_urls\": [\"${GW_URL}\"],
    \"draft_product_url\": \"${DRAFT_PRODUCT_URL}\"
  }")
  handle_res "${RES}"
  echo -e "[INFO]  ${TICK} Draft product staged"

  # Publish draft product
  echo "[INFO]  Publishing draft product..."
  RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/publish-draft-product \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}" \
    -H "content-type: application/json" \
    -d "{
    \"gateway_service_urls\": [\"${GW_URL}\"],
    \"draft_product_url\": \"${DRAFT_PRODUCT_URL}\"
  }")
  handle_res "${RES}"
  echo -e "[INFO]  ${TICK} Draft product published"
else
  # Publish product
  echo "[INFO]  Publishing product..."
  RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/publish \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}" \
    -H "content-type: multipart/form-data" \
    -F "openapi=@${CURRENT_DIR}/api.yaml;type=application/yaml" \
    -F "product=@${CURRENT_DIR}/product.yaml;type=application/yaml")
  handle_res "${RES}"
  echo -e "[INFO]  ${TICK} Product published"
fi

#*******************************************************************************
# Subscription stuff
#*******************************************************************************

# Get user registry url
echo "[INFO] Getting configured catalog user registry url for ${ORG}-catalog..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/configured-catalog-user-registries \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
USER_REGISTRY_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].user_registry_url")
$DEBUG && echo "[DEBUG] User registry url: ${USER_REGISTRY_URL}"
echo -e "[INFO] ${TICK} Got configured catalog user registry url for ${ORG}-catalog"

CORG_OWNER_USERNAME="${ORG}-corg-admin"
CORG_OWNER_PASSWORD=$(
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
  echo
)
$DEBUG && echo "[DEBUG] username: $CORG_OWNER_USERNAME"
$DEBUG && echo "[DEBUG] password: ${CORG_OWNER_PASSWORD}"
# Create consumer org owner
echo "[INFO] Creating consumer org owner..."
RES=$(curl -kLsS -X POST $USER_REGISTRY_URL/users \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"username\": \"${CORG_OWNER_USERNAME}\",
    \"email\": \"nigel@acme.org\",
    \"first_name\": \"Nigel\",
    \"last_name\": \"McNigelface\",
    \"password\": \"${CORG_OWNER_PASSWORD}\"
}")
$DEBUG && echo "[DEBUG] response: ${RES}"
handle_res "${RES}"
OWNER_URL=$(echo "${OUTPUT}" | $JQ -r ".url")
$DEBUG && echo "[DEBUG] Owner url: ${OWNER_URL}"
if [[ $OWNER_URL == "null" ]]; then
  # Get existing owner
  echo "[INFO] Getting existing consumer org owner..."
  # user registry naming convention: {catalog-name}-catalog
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/user-registries/$ORG/${CATALOG}-catalog/users \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  OWNER_URL=$(echo "${OUTPUT}" | $JQ -r '.results[] | select(.username == "'${ORG}-corg-admin'").url')
  $DEBUG && echo "[DEBUG] Owner url: ${OWNER_URL}"
  echo -e "[INFO] ${TICK} Got owner url"
else
  echo -e "[INFO] ${TICK} Consumer org owner created"

  # Store consumer org owner creds
  cat <<EOF | oc apply -n ${MAIN_NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${CORG_OWNER_USERNAME}-creds
type: Opaque
stringData:
  username: ${CORG_OWNER_USERNAME}
  password: ${CORG_OWNER_PASSWORD}
EOF

fi

# Create consumer org
echo "[INFO] Creating consumer org..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/consumer-orgs \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"title\": \"${C_ORG}\",
    \"name\": \"${C_ORG}\",
    \"owner_url\": \"${OWNER_URL}\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Consumer org created"

# Create an app
echo "[INFO] Creating application..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/consumer-orgs/$ORG/$CATALOG/$C_ORG/apps \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"title\": \"${DEMO_NAME} app\",
    \"name\": \"${APP}\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Application created"

# Get product url
echo "[INFO] Getting url for product $PRODUCT..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/products/$PRODUCT \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
PRODUCT_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].url")
$DEBUG && echo "[DEBUG] Product url: ${PRODUCT_URL}"
echo -e "[INFO] ${TICK} Got product url"

# Create an subscription
echo "[INFO] Creating subscription..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/apps/$ORG/$CATALOG/$C_ORG/$APP/subscriptions \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"product_url\": \"${PRODUCT_URL}\",
    \"plan\": \"default-plan\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Subscription created"

echo "[INFO]  Getting client id..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/credentials \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
CLIENT_ID=$(echo "${RES}" | $JQ -r '.results[] | select(.name | contains("'${APP}'")).client_id')
$DEBUG && echo "[DEBUG] Client id: ${CLIENT_ID}"
[[ $CLIENT_ID == "null" ]] && echo -e "[ERROR] ${CROSS} Couldn't get client id" && exit 1
echo -e "[INFO]  ${TICK} Got client id"


if [[ "$DEMO_NAME" == "ddd" ]]; then
  ENDPOINT_SECRET_NAME="${DEMO_NAME}-${ENVIRONMENT}-api-endpoint-client-id"
else
  ENDPOINT_SECRET_NAME="${DEMO_NAME}-api-endpoint-client-id"
fi

echo "[INFO]  Creating secret ${ENDPOINT_SECRET_NAME}"
BASE_PATH=$(grep 'basePath:' ${CURRENT_DIR}/api.yaml | head -1 | awk '{print $2}')
$DEBUG && echo "[DEBUG] BASE_PATH: ${BASE_PATH}"
HOST="https://$(oc get route -n $MAIN_NAMESPACE ${RELEASE}-gw-gateway -o jsonpath='{.spec.host}')/$ORG/$CATALOG$BASE_PATH"
$DEBUG && echo "[DEBUG] HOST: ${HOST}"

# Store api endpoint & client id in secret
cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${ENDPOINT_SECRET_NAME}
type: Opaque
stringData:
  api: ${HOST}
  cid: ${CLIENT_ID}
EOF
echo -e "[INFO]  ${TICK} Secret created"
