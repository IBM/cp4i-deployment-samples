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
CATALOG=${ORG}-catalog
C_ORG=${ORG}-corp
APP=ddd-app

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
[[ -z $PLATFORM_API_EP ]] && echo -e "[ERROR] ${CROSS} APIC platform api route doesn't exit" && exit 1
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
for i in `seq 1 5`; do
  ACE_API_ROUTE=$(oc get routes | grep -i ace-api-int-srv-http-$NAMESPACE | awk '{print $2}')
  if [[ -z $ACE_API_ROUTE ]]; then
    echo "Waiting for ace api route (Attempt $i of 5)."
    echo "Checking again in one minute..."
    sleep 60
  else
    $DEBUG && echo "[DEBUG] ACE_API_ROUTE=${ACE_API_ROUTE}"
    break
  fi
done
[[ -z $ACE_API_ROUTE ]] && echo -e "[ERROR] ${CROSS} ace api route doesn't exit" && exit 1
echo -e "[INFO]  ${TICK} Cluster info gathered"

function handle_res {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  echo "[DEBUG] ${body}"
  echo "[DEBUG] ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "400" ]]; then
    if [[ $body =~ ".*already exists.*" ]]; then
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

# Run some tests

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

# Create configmap for org info
echo "[INFO] Creating configmap ${ORG}-info"
oc create configmap ${ORG}-info \
  --from-literal=ORG=$ORG \
  --from-literal=CATALOG=$CATALOG \

# Get user registry url
echo "[INFO] Getting configured catalog user registry url for ${ORG}-catalog..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/configured-catalog-user-registries \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
USER_REGISTRY_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].user_registry_url")
$DEBUG && echo "[DEBUG] User registry url: ${USER_REGISTRY_URL}"
echo -e "[INFO] ${tick} Got configured catalog user registry url for ${ORG}-catalog"

# Create consumer org owner
echo "[INFO] Creating consumer org owner..."
RES=$(curl -kLsS -X POST $USER_REGISTRY_URL/users \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"username\": \"${ORG}-corg-admin\",
    \"email\": \"nigel@acme.org\",
    \"first_name\": \"Nigel\",
    \"last_name\": \"McNigelface\",
    \"password\": \"!n0r1t5@C\"
}")
handle_res "${RES}"
OWNER_URL=$(echo "${OUTPUT}" | $JQ -r ".url")
$DEBUG && echo "[DEBUG] Owner url: ${OWNER_URL}"
echo -e "[INFO] ${tick} Consumer org owner created"

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
echo -e "[INFO] ${tick} Consumer org created"

# Create an app
echo "[INFO] Creating application..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/consumer-orgs/$ORG/$CATALOG/$C_ORG/apps \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"title\": \"ddd app\",
    \"name\": \"${APP}\"
}")
handle_res "${RES}"
echo -e "[INFO] ${tick} Application created"

# Get product url
echo "[INFO] Getting url for product $PRODUCT..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/products/$PRODUCT \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
PRODUCT_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].url")
$DEBUG && echo "[DEBUG] Product url: ${PRODUCT_URL}"
echo -e "[INFO] ${tick} Got product url"

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
echo -e "[INFO] ${tick} Subscription created"
