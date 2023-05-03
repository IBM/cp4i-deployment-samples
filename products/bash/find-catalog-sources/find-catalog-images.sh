#!/bin/bash

SCRIPT_DIR=$(dirname $0)

: ${CLOUDCTL:=cloudctl}

${CLOUDCTL} version

CASE_REPO_PATH=https://github.com/IBM/cloud-pak/raw/master/repo/case
CASE_NAMES="ibm-cp-common-services ibm-apiconnect ibm-appconnect ibm-aspera-hsts-operator ibm-cloud-databases-redis ibm-datapower-operator ibm-eventstreams ibm-integration-asset-repository ibm-integration-platform-navigator ibm-mq"

SCRATCH=$(mktemp -d)
mkdir -p $SCRATCH

mkdir "${SCRATCH}/cases"
export CASES_DIR="${SCRATCH}/cases"

for CASE_NAME in ${CASE_NAMES}; do
  EXTRA_FLAGS=""
  retry_count=0
  if [[ "${CASE_NAME}" == "ibm-cp-common-services" ]]; then
    echo "Using version 1.18 of the CS case, which should be 3.22.x of the operator"
    EXTRA_FLAGS="--version 1.18"
  fi
  echo "Saving case for ${CASE_NAME}"
  until ${CLOUDCTL} case save \
          --repo $CASE_REPO_PATH \
          --case $CASE_NAME \
          --no-dependency \
          --outputdir "${CASES_DIR}" \
          $EXTRA_FLAGS ; do
    if [ $retry_count -gt 10 ]; then
      exit 1
    fi
    retry_count=$((retry_count + 1))
  done
done

ls -ltr ${CASES_DIR}/*.tgz

CATALOG_IMAGES=$(grep -h -e "catalog" ${CASES_DIR}/*-images.csv | grep -e ",amd64,")
FIXED_DATA_JSON='
{
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
  "ibm-cloud-databases-redis-catalog": {
    "envVarPrefix": "REDIS",
    "catalogName": "aspera-redis-operators",
    "displayNamePrefix": "Redis for Aspera Operators"
  },
  "ibm-common-service-catalog": {
    "envVarPrefix": "COMMON_SERVICES",
    "catalogName": "opencloud-operators",
    "displayNamePrefix": "IBMCS Operators"
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

echo "No problems found, creating catalogsource yaml:"
echo ""
echo ""
echo ""

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
    CATALOG_NAME=${catalog_name}
    CATALOG_IMAGE="${registry}/${image_name}@${digest}"
    CATALOG_DISPLAY_NAME="${displayNamePrefix} ${version}"
    echo "---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOG_NAME}
  namespace: openshift-marketplace
spec:
  displayName: \"${CATALOG_DISPLAY_NAME}\"
  image: ${CATALOG_IMAGE}
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m"
  fi
done
