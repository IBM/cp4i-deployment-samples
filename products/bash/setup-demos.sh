#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -i : <input.yaml> (string), full path to input yaml
#   -o : <output.yaml> (string), full path to output yaml
#
# USAGE:
#   ./setup-demos.sh -i input.yaml -o output.yaml

function divider {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage {
    echo "Usage: $0 -i input.yaml -o output.yaml"
    divider
    exit 1
}

while getopts "i:o:" opt; do
  case ${opt} in
    i ) INPUT_YAML_FILE="$OPTARG"
      ;;
    o ) OUTPUT_YAML_FILE="$OPTARG"
      ;;
    \? ) usage;
      ;;
  esac
done

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
SCRIPT_DIR=$(dirname $0)
DEBUG=true


function product_set_defaults {
  PRODUCT_JSON=${1}
  PRODUCT_TYPE=$(echo ${PRODUCT_JSON} | jq -r '.type')
  case ${PRODUCT_TYPE} in
    aceDashboard) DEFAULTS='{"name":"ace-dashboard-demo"}' ;;
    aceDesigner)  DEFAULTS='{"name":"ace-designer-demo"}' ;;
    apic)         DEFAULTS='{"name":"ademo","emailAddress":"your@email.address","mailServerHost":"smtp.mailtrap.io","mailServerPassword":"<your-password>","mailServerPort":2525,"mailServerUsername":"<your-username>"}' ;;
    assetRepo)    DEFAULTS='{"name":"ar-demo"}' ;;
    eventStreams) DEFAULTS='{"name":"es-demo"}' ;;
    mq)           DEFAULTS='{"name":"mq-demo"}' ;;
    navigator)    DEFAULTS='{"name":"navigator"}' ;;
    tracing)      DEFAULTS='{"name":"tracing-demo"}' ;;
    *)
      echo -e "$cross ERROR: Unknown product type: ${PRODUCT_TYPE}" 1>&2
      exit 1
      ;;
  esac

  for row in $(echo "${DEFAULTS}" | jq -r 'to_entries[] | @base64'); do
    KEY=$(echo ${row} | base64 --decode | jq -r '.key')
    if [[ "$(echo "$PRODUCT_JSON" | jq -r 'has("'$KEY'")')" == "false" ]]; then
      VALUE=$(echo ${row} | base64 --decode | jq -c '.value')
      PRODUCT_JSON=$(echo "$PRODUCT_JSON" | jq -c '.'$KEY' = '$VALUE)
    fi
  done

  echo "${PRODUCT_JSON}"
}

function product_fixup_namespace {
  PRODUCT_JSON=${1}
  PRODUCT_NAMESPACE=$(echo ${PRODUCT_JSON} | jq -r '.namespace')
  PRODUCT_NAMESPACE_SUFFIX=$(echo ${PRODUCT_JSON} | jq -r '.namespaceSuffix')

  if [[ -z "$PRODUCT_NAMESPACE_SUFFIX" ]] || [[ "$PRODUCT_NAMESPACE_SUFFIX" == "null" ]]; then
    if [[ -z "$PRODUCT_NAMESPACE" ]] || [[ "$PRODUCT_NAMESPACE" == "null" ]]; then
      PRODUCT_JSON=$(echo ${PRODUCT_JSON} | jq -c '.namespace="'${NAMESPACE}'"')
    fi
  else
    if [[ -z "$PRODUCT_NAMESPACE" ]] || [[ "$PRODUCT_NAMESPACE" == "null" ]]; then
      PRODUCT_JSON=$(echo ${PRODUCT_JSON} | jq -c '.namespace="'${NAMESPACE}${PRODUCT_NAMESPACE_SUFFIX}'" | del(.namespaceSuffix)')
    else
      echo -e "$cross ERROR: Cannot support both namespace and namespaceSuffix for the same product" 1>&2
      exit 1
    fi
  fi

  echo "${PRODUCT_JSON}"
}

function merge_product {
  PRODUCT_JSON=${1}
  PRODUCT_ARRAY_JSON=${2}

  PRODUCT_JSON=$(product_set_defaults $PRODUCT_JSON)
  PRODUCT_JSON=$(product_fixup_namespace $PRODUCT_JSON)

  TYPE=$(echo "${PRODUCT_JSON}" | jq -r '.type')
  NAME=$(echo "${PRODUCT_JSON}" | jq -r '.name')
  NAMESPACE=$(echo "${PRODUCT_JSON}" | jq -r '.namespace')

  MATCH=$(echo "${PRODUCT_ARRAY_JSON}" | jq -c '.[] | select(.type == "'$TYPE'" and .name == "'$NAME'" and .namespace == "'$NAMESPACE'")')
  if [[ -z $MATCH ]]; then
    # Add in the new product
    PRODUCT_ARRAY_JSON=$(echo $PRODUCT_ARRAY_JSON | jq -c '. += ['${PRODUCT_JSON}']')
  else
    ENABLED=$(echo "${PRODUCT_JSON}" | jq -r '.enabled')
    if [[ "$ENABLED" == "true" ]]; then
      # Filter out the old product from the array
      PRODUCT_ARRAY_JSON=$(echo "${PRODUCT_ARRAY_JSON}" | jq -c 'map(select(.type == "'$TYPE'" and .name == "'$NAME'" and .namespace == "'$NAMESPACE'" | not))')

      # Re add the old product with enabled=true
      # TODO Should we merge any other fields for MATCH/PRODUCT_JSON?
      MATCH=$(echo "${MATCH}" | jq -c '.enabled = true')
      PRODUCT_ARRAY_JSON=$(echo $PRODUCT_ARRAY_JSON | jq -c '. += ['${MATCH}']')
    fi
  fi

  echo ${PRODUCT_ARRAY_JSON}
}

function merge_addon {
  ADDON_JSON=${1}
  ADDON_ARRAY_JSON=${2}

  TYPE=$(echo "${ADDON_JSON}" | jq -r '.type')

  MATCH=$(echo "${ADDON_ARRAY_JSON}" | jq -c '.[] | select(.type == "'$TYPE'")')
  if [[ -z $MATCH ]]; then
    # Add in the new addon
    ADDON_ARRAY_JSON=$(echo $ADDON_ARRAY_JSON | jq -c '. += ['${ADDON_JSON}']')
  else
    ENABLED=$(echo "${ADDON_JSON}" | jq -r '.enabled')
    if [[ "$ENABLED" == "true" ]]; then
      # Filter out the old addon from the array
      ADDON_ARRAY_JSON=$(echo "${ADDON_ARRAY_JSON}" | jq -c 'map(select(.type == "'$TYPE'" | not))')

      # Re add the old addon with enabled=true
      # TODO Should we merge any other fields for MATCH/ADDON_JSON?
      MATCH=$(echo "${MATCH}" | jq -c '.enabled = true')
      ADDON_ARRAY_JSON=$(echo $ADDON_ARRAY_JSON | jq -c '. += ['${MATCH}']')
    fi
  fi

  echo ${ADDON_ARRAY_JSON}
}

#-------------------------------------------------------------------------------------------------------------------
# Validate the paramaters passed in
#-------------------------------------------------------------------------------------------------------------------
missingParams="false"
if [[ -z "${INPUT_YAML_FILE// }" ]]; then
  echo -e "$cross ERROR: INPUT_YAML_FILE is empty. Please provide a value for '-i' parameter." 1>&2
  missingParams="true"
fi

if [[ -z "${OUTPUT_YAML_FILE// }" ]]; then
  echo -e "$cross ERROR: OUTPUT_YAML_FILE is empty. Please provide a value for '-o' parameter." 1>&2
  missingParams="true"
fi
if [[ "$missingParams" == "true" ]]; then
  divider
  exit 1
fi

#-------------------------------------------------------------------------------------------------------------------
# Output the parameters
#-------------------------------------------------------------------------------------------------------------------
echo -e "$info Script directory: '$SCRIPT_DIR'"
echo -e "$info Input yaml file: '$INPUT_YAML_FILE'"
echo -e "$info Output yaml file : '$OUTPUT_YAML_FILE'"

#-------------------------------------------------------------------------------------------------------------------
# Validate the prereqs
#-------------------------------------------------------------------------------------------------------------------
missingPrereqs="false"
yq --version
if [ $? -ne 0 ]; then
  echo -e "$cross ERROR: yq needs to be installed before running this script" 1>&2
  missingPrereqs="true"
fi
jq --version
if [ $? -ne 0 ]; then
  echo -e "$cross ERROR: jq needs to be installed before running this script" 1>&2
  missingPrereqs="true"
fi
oc version --client
if [ $? -ne 0 ]; then
  echo -e "$cross ERROR: oc needs to be installed before running this script" 1>&2
  missingPrereqs="true"
fi
if [[ "$missingPrereqs" == "true" ]]; then
  divider
  exit 1
fi

#-------------------------------------------------------------------------------------------------------------------
# Read in the input yaml and convert to json
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && echo "[DEBUG] Converting $INPUT_YAML_FILE into json"
JSON=$(yq r -j $INPUT_YAML_FILE)
$DEBUG && echo "[DEBUG] Got the following JSON for $INPUT_YAML_FILE:"
$DEBUG && echo $JSON | jq .

#-------------------------------------------------------------------------------------------------------------------
# Extract information from the yaml
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && echo "[DEBUG] Get storage classes and branch from $INPUT_YAML_FILE"
GENERAL=$(echo $JSON | jq -r .spec.general)
BLOCK_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.block | if has("class") then .class else "cp4i-block-performance" end')
FILE_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.file | if has("class") then .class else "ibmc-file-gold-gid" end')
SAMPLES_REPO_BRANCH=$(echo $GENERAL | jq -r 'if has("samplesRepoBranch") then .samplesRepoBranch else "main" end')
NAMESPACE=$(echo $JSON | jq -r .metadata.namespace)
REQUIRED_DEMOS_JSON=$(echo $JSON | jq -c '.spec | if has("demos") then .demos else {} end')
REQUIRED_PRODUCTS_JSON=$(echo $JSON | jq -c '.spec | if has("products") then .products else [] end')
REQUIRED_ADDONS_JSON=$(echo $JSON | jq -c '.spec | if has("addons") then .addons else [] end')
STATUS=$(echo $JSON | jq -r .status)

echo -e "$info Block storage class: '$BLOCK_STORAGE_CLASS'"
echo -e "$info File storage class: '$FILE_STORAGE_CLASS'"
echo -e "$info Samples repo branch: '$SAMPLES_REPO_BRANCH'"
echo -e "$info Namespace: '$NAMESPACE'"

#-------------------------------------------------------------------------------------------------------------------
# If all demos enabled then add all demos
#-------------------------------------------------------------------------------------------------------------------
ALL_DEMOS_ENABLED=$(echo $REQUIRED_DEMOS_JSON | jq -r '.all | if has("enabled") then .enabled else "false" end')
$DEBUG && echo -e "$info All demos enabled: '$ALL_DEMOS_ENABLED'"
if [[ "${ALL_DEMOS_ENABLED}" == "true" ]]; then
  REQUIRED_DEMOS_JSON='{"cognitiveCarRepair": {"enabled": true},"drivewayDentDeletion": {"enabled": true},"eventEnabledInsurance": {"enabled": true}}'
else
  REQUIRED_DEMOS_JSON=$(echo $REQUIRED_DEMOS_JSON | jq -c 'del(.all)')
fi

#-------------------------------------------------------------------------------------------------------------------
# Loop through the products and set the name/namespace and merge the products into the array using type/namespace/name as the identifier
#-------------------------------------------------------------------------------------------------------------------
NEW_REQUIRED_PRODUCTS_JSON="[]"
for row in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '.[] | @base64'); do
  PRODUCT_JSON=$(echo ${row} | base64 --decode)
  NEW_REQUIRED_PRODUCTS_JSON=$(merge_product ${PRODUCT_JSON} ${NEW_REQUIRED_PRODUCTS_JSON})
done
REQUIRED_PRODUCTS_JSON=${NEW_REQUIRED_PRODUCTS_JSON}

#-------------------------------------------------------------------------------------------------------------------
# For each demo add to the requiredProducts/requiredAddons lists, including the namespaces
#-------------------------------------------------------------------------------------------------------------------
for DEMO in $(echo $REQUIRED_DEMOS_JSON | jq -r 'to_entries[] | select( .value.enabled == true ) | .key'); do
  PRODUCTS_FOR_DEMO=""
  ADDONS_FOR_DEMO=""
  case ${DEMO} in
    cognitiveCarRepair)
      PRODUCTS_FOR_DEMO='
      {"enabled":true,"type":"aceDashboard"}
      {"enabled":true,"type":"aceDesigner"}
      {"enabled":true,"type":"apic"}
      {"enabled":true,"type":"assetRepo"}
      {"enabled":true,"type":"tracing"}
      '
      ADDONS_FOR_DEMO=''
      ;;
    drivewayDentDeletion)
      PRODUCTS_FOR_DEMO='
      {"enabled":true,"type":"aceDashboard"}
      {"enabled":true,"type":"apic"}
      {"enabled":true,"type":"tracing"}
      '
      # Disabled as we no longer want a separate namespace for test. The following is an example
      # of how this could work if we want to re-add this support later.
      # {"enabled":true,"namespaceSuffix":"-ddd-test","type":"aceDashboard"}
      # {"enabled":true,"namespaceSuffix":"-ddd-test","type":"navigator"}
      ADDONS_FOR_DEMO='
      {"enabled":true,"type":"postgres"}
      {"enabled":true,"type":"ocpPipelines"}
      '
      ;;
    eventEnabledInsurance)
      PRODUCTS_FOR_DEMO='
      {"enabled":true,"type":"aceDashboard"}
      {"enabled":true,"type":"apic"}
      {"enabled":true,"type":"eventStreams"}
      {"enabled":true,"type":"tracing"}
      '
      ADDONS_FOR_DEMO='
      {"enabled":true,"type":"postgres"}
      {"enabled":true,"type":"elasticSearch"}
      {"enabled":true,"type":"ocpPipelines"}
      '
      ;;

    *)
      echo -e "$cross ERROR: Unknown demo: ${DEMO}" 1>&2
      exit 1
      ;;
  esac

  for PRODUCT_JSON in $PRODUCTS_FOR_DEMO; do
    REQUIRED_PRODUCTS_JSON=$(merge_product ${PRODUCT_JSON} ${REQUIRED_PRODUCTS_JSON})
  done
  for ADDON_JSON in $ADDONS_FOR_DEMO; do
    REQUIRED_ADDONS_JSON=$(merge_addon ${ADDON_JSON} ${REQUIRED_ADDONS_JSON})
  done
done

#-------------------------------------------------------------------------------------------------------------------
# Add the required addons
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider
$DEBUG && echo "Addons:"
for row in $(echo "${REQUIRED_ADDONS_JSON}" | jq -r '.[] | select(.enabled == true ) | @base64'); do
  ADDON_JSON=$(echo ${row} | base64 --decode)
  $DEBUG && echo $ADDON_JSON | jq .
done

#-------------------------------------------------------------------------------------------------------------------
# Add the required namespaces
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider
$DEBUG && echo "Namespaces:"
for namespace in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '[ .[] | select(.enabled == true ) | .namespace ] | unique | .[]'); do
  $DEBUG && echo $namespace
done

#-------------------------------------------------------------------------------------------------------------------
# Add the required products
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider
$DEBUG && echo "Products:"
for row in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '.[] | select(.enabled == true ) | @base64'); do
  PRODUCT_JSON=$(echo ${row} | base64 --decode)
  $DEBUG && echo $PRODUCT_JSON | jq .
done

#-------------------------------------------------------------------------------------------------------------------
# Add the required demos
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider
$DEBUG && echo "Demos:"
for DEMO in $(echo $REQUIRED_DEMOS_JSON | jq -r 'to_entries[] | select( .value.enabled == true ) | .key'); do
  $DEBUG && echo $DEMO
done
