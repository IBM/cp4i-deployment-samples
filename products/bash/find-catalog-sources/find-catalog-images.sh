#!/bin/bash

SCRIPT_DIR=$(dirname $0)

CASE_VERSION=

while getopts "v:" opt; do
  case ${opt} in
  v)
    CASE_VERSION="$OPTARG"
    ;;
  esac
done

if [[ -z "$CASE_VERSION" ]]; then
  CASE_VERSION=$(${SCRIPT_DIR}/get-latest.sh)
fi

: ${CLOUDCTL:=cloudctl}
: ${GIT:=git}

${CLOUDCTL} version
${GIT} version

SCRATCH=$(mktemp -d)
mkdir -p $SCRATCH

CASE_REPO_PATH=https://github.com/IBM/cloud-pak/raw/master/repo/case
CASE_NAME=ibm-cp-integration
echo "CASE_VERSION=${CASE_VERSION}"

mkdir "${SCRATCH}/cases"
export CASES="${SCRATCH}/cases"
${CLOUDCTL} case save \
        --repo $CASE_REPO_PATH \
        --case $CASE_NAME \
        --version $CASE_VERSION \
        --outputdir "${CASES}"

CATALOG_IMAGES=$(grep -h -e "catalog" ${SCRATCH}/cases/*-images.csv | grep -e ",amd64,")
FIXED_DATA_JSON='
{
  "ibm-ai-wmltraining-operator-catalog": {
    "envVarPrefix": "WML_TRAINING",
    "catalogName": "ibm-ai-wmltraining-catalog",
    "displayNamePrefix": "WML Training Operators"
  },
  "ibm-apiconnect-catalog": {
    "envVarPrefix": "APIC",
    "catalogName": "apic-operators",
    "displayNamePrefix": "APIC Operators"
  },
  "appconnect-operator-catalog": {
    "envVarPrefix": "ACE",
    "catalogName": "ace-operators",
    "displayNamePrefix": "ACE Operators"
  },
  "aspera-hsts-catalog": {
    "envVarPrefix": "ASPERA",
    "catalogName": "aspera-operators",
    "displayNamePrefix": "Aspera Operators"
  },
  "ibm-automation-foundation-core-catalog": {
    "envVarPrefix": "IAF",
    "catalogName": "automation-base-pak-operators",
    "displayNamePrefix": "IBMABP Operators"
  },
  "ibm-cloud-databases-redis-catalog": {
    "envVarPrefix": "REDIS",
    "catalogName": "aspera-redis-operators",
    "displayNamePrefix": "Redis for Aspera Operators"
  },
  "couchdb-operator-catalog": {
    "envVarPrefix": "COUCHDB",
    "catalogName": "couchdb-operators",
    "displayNamePrefix": "IBM CouchDB Operators"
  },
  "ibm-common-service-catalog": {
    "envVarPrefix": "COMMON_SERVICES",
    "catalogName": "opencloud-operators",
    "displayNamePrefix": "IBMCS Operators"
  },
  "ibm-cp-integration-catalog": {
    "ignore": true
  },
  "datapower-operator-catalog": {
    "envVarPrefix": "DATAPOWER",
    "catalogName": "dp-operators",
    "displayNamePrefix": "DP Operators"
  },
  "ibm-eventstreams-catalog": {
    "envVarPrefix": "EVENT_STREAMS",
    "catalogName": "es-operators",
    "displayNamePrefix": "ES Operators"
  },
  "ibm-integration-asset-repository-catalog": {
    "envVarPrefix": "ASSET_REPO",
    "catalogName": "ar-operators",
    "displayNamePrefix": "AR Operators"
  },
  "ibm-integration-operations-dashboard-catalog": {
    "envVarPrefix": "OPERATIONS_DASHBOARD",
    "catalogName": "od-operators",
    "displayNamePrefix": "OD Operators"
  },
  "ibm-integration-platform-navigator-catalog": {
    "envVarPrefix": "NAVIGATOR",
    "catalogName": "pn-operators",
    "displayNamePrefix": "PN Operators"
  },
  "ibm-mq-operator-catalog": {
    "envVarPrefix": "MQ",
    "catalogName": "mq-operators",
    "displayNamePrefix": "MQ Operators"
  }
}'

echo "Comparing images to those expected..."
FOUND_ERRORS=false
for line in $CATALOG_IMAGES; do
  image_name=$(echo $line | cut -d, -f 2)
  catalog_name=$(echo $image_name | cut -d/ -f 2)
  if [[ "$(echo "$FIXED_DATA_JSON" | jq 'has("'$catalog_name'")')" == "false" ]]; then
    echo "Found the following in the list of catalog images but not supported by create-catalog-sources.sh:"
    echo "  ${line}"
    FOUND_ERRORS=true
  fi
done

for catalog_name in $(echo "${FIXED_DATA_JSON}" | jq -r 'keys[]'); do
  echo "$CATALOG_IMAGES" | grep -e "$catalog_name" >/dev/null 2>&1
  RESULT=$?
  if [[ $RESULT == 1 ]] ; then
    FOUND_ERRORS=true
    echo "Catalog image not found for catalog: $catalog_name"
  fi
done

if [[ "$FOUND_ERRORS" == "true" ]]; then
  exit 1
fi

echo "No problems found, creating env vars..."

for line in $CATALOG_IMAGES; do
  image_name=$(echo $line | cut -d, -f 2)
  catalog_name=$(echo $image_name | cut -d/ -f 2)
  data=$(echo "$FIXED_DATA_JSON" | jq -r '.["'$catalog_name'"]')
  ignore=$(echo "$data" | jq -r '.ignore')
  if [[ "${ignore}" != "true" ]]; then
    registry=$(echo $line | cut -d, -f 1)
    tag=$(echo $line | cut -d, -f 3)
    digest=$(echo $line | cut -d, -f 4)
    version=$(echo $tag | cut -d- -f 1)
    envVarPrefix=$(echo "$data" | jq -r '.envVarPrefix')
    catalogName=$(echo "$data" | jq -r '.catalogName')
    displayNamePrefix=$(echo "$data" | jq -r '.displayNamePrefix')
    echo "${envVarPrefix}_CATALOG_NAME=${catalog_name}"
    echo "${envVarPrefix}_CATALOG_IMAGE=${registry}/${image_name}@${digest}"
    echo "${envVarPrefix}_CATALOG_DISPLAY_NAME=\"${displayNamePrefix} ${version}\""
  fi
done
