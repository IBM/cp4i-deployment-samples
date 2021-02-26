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
#   -i : <input.yaml/input.json> (string), full path to input yaml/json
#   -o : <output.yaml/output.json> (string), full path to output yaml/json
#
# USAGE:
#   ./setup-demos.sh -i input.yaml/json -o output.yaml/json

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -i input.yaml/json -o output.yaml/json"
  divider
  exit 1
}

while getopts "i:o:" opt; do
  case ${opt} in
  i)
    INPUT_FILE="$OPTARG"
    ;;
  o)
    OUTPUT_FILE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
INFO="\xE2\x84\xB9"
SCRIPT_DIR=$(dirname $0)
FAILURE_CODE=1
SUCCESS_CODE=0
CONDITION_ELEMENT_OBJECT='{"lastTransitionTime":"","message":"","reason":"","status":"","type":""}'
NAMESPACE_OBJECT_FOR_STATUS='{"name":""}'
TRACING_ENABLED=false
ADDON_OBJECT_FOR_STATUS='{"type":"", "installed":"", "readyToUse":""}'
PRODUCT_OBJECT_FOR_STATUS='{"name":"","type":"", "namespace":"", "installed":"", "readyToUse":""}'
DEFAULT_DEMO_VERSION="2020.3.1-1"
DEMO_OBJECT_FOR_STATUS='{"name":"", "installed":"", "readyToUse":""}'
SAMPLES_REPO_BRANCH="main"
MISSING_PARAMS="false"
MISSING_PREREQS="false"

# cognitive car repair demo list
COGNITIVE_CAR_REPAIR_PRODUCTS_LIST=("aceDashboard" "aceDesigner" "apic" "assetRepo" "tracing")
COGNITIVE_CAR_REPAIR_ADDONS_LIST=()
# driveway dent deletion demo list
DRIVEWAY_DENT_DELETION_PRODUCTS_LIST=("mq" "aceDashboard" "apic" "tracing")
DRIVEWAY_DENT_DELETION_ADDONS_LIST=("postgres" "ocpPipelines")
# event insurance demo list
EVENT_ENABLED_INSURANCE_PRODUCTS_LIST=("mq" "aceDashboard" "apic" "eventStreams" "tracing")
EVENT_ENABLED_INSURANCE_ADDONS_LIST=("postgres" "elasticSearch" "ocpPipelines")
# mapping assist demo list
MAPPING_ASSIST_PRODUCTS_LIST=("aceDesigner")
MAPPING_ASSIST_ADDONS_LIST=()
# ace weather chatbot demo list
ACE_WEATHER_CHATBOT_PRODUCTS_LIST=("aceDashboard" "aceDesigner" "apic" "assetRepo" "tracing")
ACE_WEATHER_CHATBOT_ADDONS_LIST=()

# Default release name variables
MQ_RELEASE_NAME="mq-demo"
ACE_DESIGNER_RELEASE_NAME="ace-designer-demo"
ASSET_REPOSITORY_RELEASE_NAME="ar-demo"
ACE_DASHBOARD_RELEASE_NAME="ace-dashboard-demo"
APIC_RELEASE_NAME="ademo"
EVENT_STREAM_RELEASE_NAME="es-demo"
TRACING_RELEASE_NAME="tracing-demo"

# Default APIC Configuration
DEFAULT_APIC_EMAIL_ADDRESS="your@email.address"
DEFAULT_APIC_MAIL_SERVER_HOST="smtp.mailtrap.io"
DEFAULT_APIC_MAIL_SERVER_PORT="2525"
DEFAULT_APIC_MAIL_SERVER_USERNAME="<your-username>"
DEFAULT_APIC_MAIL_SERVER_PASSWORD="<your-password>"

# failed install/setup list
declare -a FAILED_INSTALL_PRODUCTS_LIST
declare -a FAILED_INSTALL_ADDONS_LIST
declare -a FAILED_INSTALL_DEMOS_LIST

# set to true to print development logs
export DEBUG=true

#-------------------------------------------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------------------------------------------

function build_required_demo_addons_and_products() {
  ELEMENT_FOR_DEMO=${1}
  REQUIRED_OBJECT_FOR_DEMO=${2}
  REQUIRED_OBJECT_FOR_DEMO=$(echo $REQUIRED_OBJECT_FOR_DEMO | jq -c '. += ''{"'$ELEMENT_FOR_DEMO'":true}'' ')
  echo ${REQUIRED_OBJECT_FOR_DEMO}
}

#----------------------------------------------------

function update_conditions() {
  MESSAGE=${1}           # Message to update status condition with
  REASON=${2}            # command type
  CONDITION_TYPE="Error" # for the type in conditions
  TIMESTAMP=$(date -u +%FT%T.%Z)

  echo -e "\n$CROSS [ERROR] $MESSAGE"
  $DEBUG && echo -e "\n$INFO [DEBUG] update_conditions(): reason($REASON) - conditionType($CONDITION_TYPE) - timestamp($TIMESTAMP)"

  # update condition array
  CONDITION_TO_ADD=$(echo $CONDITION_ELEMENT_OBJECT | jq -r '.message="'"$MESSAGE"'" | .status="True" | .type="'$CONDITION_TYPE'" | .lastTransitionTime="'$TIMESTAMP'" | .reason="'$REASON'" ')
  # add condition to condition array
  STATUS=$(echo $STATUS | jq -c '.conditions += ['"${CONDITION_TO_ADD}"']')
  $DEBUG && echo -e "\n$INFO [DEBUG] Printing the status conditions array" && echo $STATUS | jq -r '.conditions'
}

#----------------------------------------------------

function update_phase() {
  PHASE=${1} # Pending, Running or Failed
  $DEBUG && divider && echo -e "$INFO [DEBUG] update_phase(): phase($PHASE)" && divider
  STATUS=$(echo $STATUS | jq -c '.phase="'$PHASE'"')
}

#----------------------------------------------------

function check_phase_and_exit_on_failed() {
  CURRENT_PHASE=$(echo $STATUS | jq -r '.phase')
  # if the current phase is failed, then exit status (case insensitive checking)
  if echo $CURRENT_PHASE | grep -iqF failed; then
    echo -e "$INFO [INFO] Current installation phase is '$CURRENT_PHASE', exiting now." && divider
    exit 1
  else
    $DEBUG && divider && echo -e "$INFO [DEBUG] Current installation phase is '$CURRENT_PHASE', continuing the installation..."
  fi
}

#----------------------------------------------------

function update_addon_status() {
  ADDON_TYPE=${1}         # type of addon
  ADDON_INSTALLED=${2}    # if the addon is installed
  ADDON_READY_TO_USE=${3} # if the installed addon is configured and ready to use

  $DEBUG && divider && echo -e "$INFO [DEBUG] addonType($ADDON_TYPE) - addonInstalled($ADDON_INSTALLED) - addonReadyToUse($ADDON_READY_TO_USE)"

  # clear any existing status for the passed addon type
  STATUS=$(echo $STATUS | jq -c 'del(.addons[] | select(.type == "'$ADDON_TYPE'")) ')
  # create object and add status for each addon
  ADDON_TO_ADD_TO_STATUS=$(echo $ADDON_OBJECT_FOR_STATUS | jq -r '.type="'$ADDON_TYPE'" | .installed="'$ADDON_INSTALLED'" | .readyToUse="'$ADDON_READY_TO_USE'" ')
  # update status with new addon status
  STATUS=$(echo $STATUS | jq -c '.addons += ['"${ADDON_TO_ADD_TO_STATUS}"']')
}

#----------------------------------------------------

function update_product_status() {
  PRODUCT_NAME=${1}            # name of product
  PRODUCT_TYPE=${2}            # type of product
  PRODUCT_INSTALLED=${3}       # if the product is installed
  PRODUCT_READY_TO_USE=${4}    # if the installed product is configured and ready to use
  PRODUCT_NAMESPACE=$NAMESPACE # namespace for the product

  $DEBUG && divider && echo -e "$INFO [DEBUG] productName($PRODUCT_NAME) - productNamespace($PRODUCT_NAMESPACE) - productType($PRODUCT_TYPE) - productInstalled($PRODUCT_INSTALLED) - productReadyToUse($PRODUCT_READY_TO_USE)"

  # clear any existing status for the passed product type
  STATUS=$(echo $STATUS | jq -c 'del(.products[] | select(.type == "'$PRODUCT_TYPE'" and .name == "'$PRODUCT_NAME'" and .namespace == "'$PRODUCT_NAMESPACE'")) ')
  # create object and add status for each product
  PRODUCT_TO_ADD_TO_STATUS=$(echo $PRODUCT_OBJECT_FOR_STATUS | jq -r '.name="'$PRODUCT_NAME'" | .type="'$PRODUCT_TYPE'" | .namespace="'$PRODUCT_NAMESPACE'" | .installed="'$PRODUCT_INSTALLED'" | .readyToUse="'$PRODUCT_READY_TO_USE'" ')
  # update status with new product status
  STATUS=$(echo $STATUS | jq -c '.products += ['"${PRODUCT_TO_ADD_TO_STATUS}"']')
}

#----------------------------------------------------

function check_current_status() {
  DEMO_NAME=${1} # Save demo name
  LIST_TYPE=${2} # Save the list type
  shift 2        # Shift first 2 arguments to the left
  LIST=("$@")    # Rebuild the array with rest of passed arguments
  DEMO_CONFIGURED=false
  NOT_CONFIGURED_COUNT=0

  if [[ ${#LIST[@]} -ne 0 ]]; then
    $DEBUG && echo -e "\n$INFO [DEBUG] Received '$LIST_TYPE' list for '$DEMO_NAME': '${LIST[@]}'"
    #  Iterate the loop to read and print each array element
    for EACH_ITEM in "${LIST[@]}"; do
      if [[ "$(echo $STATUS | jq -c '."'$LIST_TYPE'"[] | select(.type == "'$EACH_ITEM'" and .installed == "true" and .readyToUse == "true") ')" == "" ]]; then
        NOT_CONFIGURED_COUNT=$((NOT_CONFIGURED_COUNT + 1))

        # add each addon/product to failed list depending on the type
        if [[ "$LIST_TYPE" == "addons" ]]; then
          # add not ready products to failed list
          FAILED_INSTALL_ADDONS_LIST+=($EACH_ITEM)
        else
          # add not ready products to failed list
          FAILED_INSTALL_PRODUCTS_LIST+=($EACH_ITEM)
        fi
      fi
    done
  else
    $DEBUG && echo -e "\n$INFO [DEBUG] Received an empty '$LIST_TYPE' list for '$DEMO_NAME'"
  fi

  if [[ $NOT_CONFIGURED_COUNT -eq 0 ]]; then
    DEMO_CONFIGURED=true
    echo -e "\n$TICK [SUCCESS] All $LIST_TYPE have been installed and configured for '$DEMO_NAME' demo"
  else
    FAILED_INSTALL_DEMOS_LIST+=($DEMO_NAME)
    update_phase "Failed"
    echo -e "\n$CROSS [ERROR] All $LIST_TYPE have not been installed/configured for '$DEMO_NAME' demo"
  fi
}

#----------------------------------------------------

function update_demo_status() {
  DEMO_NAME=${1}         # type of demo
  DEMO_INSTALLED=${2}    # if the demo is installed
  DEMO_READY_TO_USE=${3} # if the demo prereqs is configured and ready to use

  # in case empty installed status is passed, use existing value - done when running updating after prereqs script
  if [[ -z "${DEMO_INSTALLED// /}" ]]; then
    DEMO_INSTALLED=$(echo $STATUS | jq -r '.demos[] | select(.name == "'$DEMO_NAME'") | .installed ')
  fi

  $DEBUG && divider && echo -e "$INFO [DEBUG] demoName($DEMO_NAME) - demoInstalled($DEMO_INSTALLED) - demoReadyToUse($DEMO_READY_TO_USE)"

  # clear any existing status for the passed demo name
  STATUS=$(echo $STATUS | jq -c 'del(.demos[] | select(.name == "'$DEMO_NAME'")) ')
  # create object and add status for each demo
  DEMO_TO_ADD_TO_STATUS=$(echo $DEMO_OBJECT_FOR_STATUS | jq -r '.name="'$DEMO_NAME'" | .installed="'$DEMO_INSTALLED'" | .readyToUse="'$DEMO_READY_TO_USE'" ')
  # update status with new demo status
  STATUS=$(echo $STATUS | jq -c '.demos += ['"${DEMO_TO_ADD_TO_STATUS}"']')
}

#----------------------------------------------------

function set_up_demos() {
  DEMO_JSON_NAME=${1}         # demo name from input json
  DEMO_ECHO_NAME=${2}         # demo name for echo
  shift 2                     # shift first 2 parameters
  PRODUCTS_LIST=("${@:2:$1}") # Product list for demos
  shift "$(($1 + 1))"         # shift size of Product list and Product list
  ADDONS_LIST=("${@:2:$1}")   # Addon list for demos

  echo -e "$INFO [INFO] Setting up the '$DEMO_ECHO_NAME demo'\n"
  echo -e "$INFO [INFO] Checking if all addons are installed and setup for the '$DEMO_ECHO_NAME demo'"
  check_current_status "$DEMO_JSON_NAME" "addons" "${ADDONS_LIST[@]}"
  ADDONS_CONFIGURED=$DEMO_CONFIGURED
  echo -e "\n$INFO [INFO] Checking if all products are installed and setup for the '$DEMO_ECHO_NAME demo'"
  check_current_status "$DEMO_JSON_NAME" "products" "${PRODUCTS_LIST[@]}"
  PRODUCTS_CONFIGURED=$DEMO_CONFIGURED
  if [[ "$ADDONS_CONFIGURED" == "true" && "$PRODUCTS_CONFIGURED" == "true" ]]; then
    divider && echo -e "$TICK $ALL_DONE [SUCCESS] '$DEMO_ECHO_NAME demo' setup completed successfully. $ALL_DONE $TICK"
    # No pre-requisites are to be run, so setting installed and readyToUse to true
    update_demo_status "$DEMO_JSON_NAME" "true" "true"
  else
    divider && echo -e "$CROSS [ERROR] '$DEMO_ECHO_NAME demo' did not setup correctly. $CROSS"
    # If one or more products failed to setup/configure, demo is not ready to use
    update_demo_status "$DEMO_JSON_NAME" "false" "false"
  fi
}

#-------------------------------------------------------------------------------------------------------------------
# Set seconds to zero to calculate time taken for overall setup
#-------------------------------------------------------------------------------------------------------------------

SECONDS=0

#-------------------------------------------------------------------------------------------------------------------
# Validate the parameters passed in
#-------------------------------------------------------------------------------------------------------------------

if [[ -z "${INPUT_FILE// /}" ]]; then
  echo -e "$CROSS ERROR: INPUT_FILE is empty. Please provide a value for '-i' parameter." 1>&2
  MISSING_PARAMS="true"
fi

if [[ -z "${OUTPUT_FILE// /}" ]]; then
  echo -e "$CROSS ERROR: OUTPUT_FILE is empty. Please provide a value for '-o' parameter." 1>&2
  MISSING_PARAMS="true"
fi

if [[ "$MISSING_PARAMS" == "true" ]]; then
  divider
  exit 1
fi

#-------------------------------------------------------------------------------------------------------------------
# Output the parameters
#-------------------------------------------------------------------------------------------------------------------

divider && echo -e "$INFO Script directory: '$SCRIPT_DIR'"
echo -e "$INFO Input file: '$INPUT_FILE'"
echo -e "$INFO Output file : '$OUTPUT_FILE'"

#-------------------------------------------------------------------------------------------------------------------
# Validate the prereqs
#-------------------------------------------------------------------------------------------------------------------

# Only require yq to be installed if either file is not json (I.e. yaml)
if [[ "$INPUT_FILE" != *.json ]] || [[ "$OUTPUT_FILE" != *.json ]]; then
  divider && echo -e "$INFO [INFO] Checking if 'yq' is already installed...\n"
  yq --version
  if [ $? -ne 0 ]; then
    echo -e "$CROSS [ERROR] 'yq' needs to be installed before running this script" 1>&2
    MISSING_PREREQS="true"
  fi
fi

divider && echo -e "$INFO [INFO] Checking if 'jq' is already installed...\n"
jq --version
if [ $? -ne 0 ]; then
  echo -e "$CROSS [ERROR] 'jq' needs to be installed before running this script" 1>&2
  MISSING_PREREQS="true"
fi

divider && echo -e "$INFO [INFO] Checking if 'oc' is already installed...\n"
oc version
if [ $? -ne 0 ]; then
  echo -e "$CROSS [ERROR] 'oc' needs to be installed before running this script" 1>&2
  MISSING_PREREQS="true"
fi

if [[ "$MISSING_PREREQS" == "true" ]]; then
  divider
  exit 1
fi

#-------------------------------------------------------------------------------------------------------------------
# Read in the input file and, if not already json, convert to json
#-------------------------------------------------------------------------------------------------------------------

if [[ "$INPUT_FILE" == *.json ]]; then
  JSON=$(<$INPUT_FILE)
else
  $DEBUG && divider && echo -e "[DEBUG] Converting $INPUT_FILE into json" && divider
  JSON=$(yq r -j $INPUT_FILE)
fi
$DEBUG && echo -e "[DEBUG] Got the following JSON for $INPUT_FILE:\n"
$DEBUG && echo $JSON | jq . && divider

#-------------------------------------------------------------------------------------------------------------------
# Extract information from the yaml
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && echo -e "[DEBUG] Extracting the required information from the input file: $INPUT_FILE"
GENERAL=$(echo $JSON | jq -r .spec.general)
BLOCK_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.block | if has("class") then .class else "cp4i-block-performance" end')
FILE_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.file | if has("class") then .class else "ibmc-file-gold-gid" end')
SAMPLES_REPO_BRANCH=$(echo $GENERAL | jq -r 'if has("samplesRepoBranch") then .samplesRepoBranch else "'$SAMPLES_REPO_BRANCH'" end')
NAMESPACE=$(echo $JSON | jq -r .metadata.namespace)
REQUIRED_DEMOS_JSON=$(echo $JSON | jq -c '.spec | if has("demos") then .demos else {} end')
REQUIRED_PRODUCTS_JSON=$(echo $JSON | jq -c '.spec | if has("products") then .products else {} end')
REQUIRED_ADDONS_JSON=$(echo $JSON | jq -c '.spec | if has("addons") then .addons else {} end')
DEMO_VERSION=$(echo $JSON | jq -r '.spec | if has("version") then .version else "'$DEFAULT_DEMO_VERSION'" end ')
# To use for un-installation
ORIGINAL_STATUS=$(echo $JSON | jq -c .status)
APIC_CONFIGURATION=$(echo $JSON | jq -c '.spec | if has("apic") then .apic else {} end')
divider
echo -e "$INFO Block storage class: '$BLOCK_STORAGE_CLASS'"
echo -e "$INFO File storage class: '$FILE_STORAGE_CLASS'"
echo -e "$INFO Samples repo branch: '$SAMPLES_REPO_BRANCH'"
echo -e "$INFO Demo version: '$DEMO_VERSION'"
echo -e "$INFO Namespace: '$NAMESPACE'" && divider

#-------------------------------------------------------------------------------------------------------------------
# If all demos enabled then add all demos else delete all demos value and keep enabled ones
#-------------------------------------------------------------------------------------------------------------------

ALL_DEMOS_ENABLED=$(echo $REQUIRED_DEMOS_JSON | jq -r '. | if has("all") then .all else false end')
$DEBUG && echo -e "$INFO [DEBUG] All demos enabled: '$ALL_DEMOS_ENABLED'"
if [[ "${ALL_DEMOS_ENABLED}" == "true" ]]; then
  REQUIRED_DEMOS_JSON='{"cognitiveCarRepair": {"enabled": true},"drivewayDentDeletion": {"enabled": true},"eventEnabledInsurance": {"enabled": true},"mappingAssist": {"enabled": true},"weatherChatbot": {"enabled": true}}'
else
  REQUIRED_DEMOS_JSON=$(echo $REQUIRED_DEMOS_JSON | jq -c 'del(.all) | del(.[] | select(. == false))')
fi

#-------------------------------------------------------------------------------------------------------------------
# Update the required JSON with addons and products which are enabled in the CR
#-------------------------------------------------------------------------------------------------------------------

REQUIRED_PRODUCTS_JSON=$(echo $REQUIRED_PRODUCTS_JSON | jq -c 'del(.[] | select(. == false))')
REQUIRED_ADDONS_JSON=$(echo $REQUIRED_ADDONS_JSON | jq -c 'del(.[] | select(. == false))')

#-------------------------------------------------------------------------------------------------------------------
# For each demo add to the requiredProducts/requiredAddons lists, including the namespaces
#-------------------------------------------------------------------------------------------------------------------

for DEMO in $(echo $REQUIRED_DEMOS_JSON | jq -r 'keys[]'); do
  PRODUCTS_FOR_DEMO=""
  ADDONS_FOR_DEMO=""
  case ${DEMO} in
  cognitiveCarRepair)
    PRODUCTS_FOR_DEMO='
      aceDashboard
      aceDesigner
      apic
      assetRepo
      tracing
      '
    ADDONS_FOR_DEMO=''
    ;;
  drivewayDentDeletion)
    PRODUCTS_FOR_DEMO='
      mq
      aceDashboard
      apic
      tracing
      '

    # Disabled as we no longer want a separate namespace for test. The following is an example
    # of how this could work if we want to re-add this support later.
    # {"enabled":true,"namespaceSuffix":"-ddd-test","type":"aceDashboard"}
    # {"enabled":true,"namespaceSuffix":"-ddd-test","type":"navigator"}

    ADDONS_FOR_DEMO='
      postgres
      ocpPipelines
      '
    ;;
  eventEnabledInsurance)
    PRODUCTS_FOR_DEMO='
      mq
      aceDashboard
      apic
      eventStreams
      tracing
      '
    ADDONS_FOR_DEMO='
      postgres
      elasticSearch
      ocpPipelines
      '
    ;;
  mappingAssist)
    PRODUCTS_FOR_DEMO='
      aceDesigner
      '
    ADDONS_FOR_DEMO=''
    ;;
  weatherChatbot)
    PRODUCTS_FOR_DEMO='
      aceDashboard
      aceDesigner
      apic
      assetRepo
      tracing
      '
    ADDONS_FOR_DEMO=''
    ;;
  *)
    echo -e "$CROSS ERROR: Unknown demo: ${DEMO}" 1>&2
    exit 1
    ;;
  esac

  for EACH_REQUIRED_PRODUCT_FOR_DEMO in ${PRODUCTS_FOR_DEMO[@]}; do
    REQUIRED_PRODUCTS_JSON=$(build_required_demo_addons_and_products ${EACH_REQUIRED_PRODUCT_FOR_DEMO} ${REQUIRED_PRODUCTS_JSON})
  done

  for EACH_REQUIRED_ADDON_FOR_DEMO in ${ADDONS_FOR_DEMO[@]}; do
    REQUIRED_ADDONS_JSON=$(build_required_demo_addons_and_products ${EACH_REQUIRED_ADDON_FOR_DEMO} ${REQUIRED_ADDONS_JSON})
  done
done

#-------------------------------------------------------------------------------------------------------------------
# Print previous status, clear it and set new status with Phase as Pending
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider

# if previous status exists, print it
if [[ "$ORIGINAL_STATUS" != "null" ]]; then
  $DEBUG && echo -e "$INFO [DEBUG] Original status passed:\n" && echo $ORIGINAL_STATUS | jq .
fi

$DEBUG && echo -e "$INFO [DEBUG] Deleting old status, assigning new status and changing the status phase to 'Pending' as installation is starting..."
JSON=$(echo $JSON | jq -r 'del(.status) | .status.version="'$DEMO_VERSION'" | .status.conditions=[] | .status.phase="Pending" | .status.demos=[] | .status.addons=[] | .status.products=[] | .status.namespaces=[] ')
STATUS=$(echo $JSON | jq -r .status)

#-------------------------------------------------------------------------------------------------------------------
# Check if the namespace and the secret exists
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo -e "$INFO [DEBUG] Check if the '$NAMESPACE' namespace and the secret 'ibm-entitlement-key' exists...\n"

# add namespace to status if exists
oc get project $NAMESPACE 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  update_conditions "Namespace '$NAMESPACE' does not exist" "Getting"
  update_phase "Failed"
else
  echo -e "$TICK [SUCCESS] Namespace '$NAMESPACE' exists"
  NAMESPACE_TO_ADD=$(echo $NAMESPACE_OBJECT_FOR_STATUS | jq -r '.name="'$NAMESPACE'" ')
  STATUS=$(echo $STATUS | jq -c '.namespaces += ['"${NAMESPACE_TO_ADD}"']')
fi

check_phase_and_exit_on_failed
divider

# check if the secret exists in the namespace
oc get secret -n $NAMESPACE ibm-entitlement-key 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  update_conditions "Secret 'ibm-entitlement-key' not found in '$NAMESPACE' namespace" "Getting"
  update_phase "Failed"
else
  echo -e "$TICK [SUCCESS] Secret 'ibm-entitlement-key' exists in the '$NAMESPACE' namespace"
fi

check_phase_and_exit_on_failed

METADATA_NAME=$(oc get demo -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
METADATA_UID=$(oc get demo -n $NAMESPACE $METADATA_NAME -o json | jq -r '.metadata.uid')

if [[ $METADATA_NAME && $METADATA_UID != '' ]]; then
  cat <<EOF | oc apply --namespace ${NAMESPACE} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: operator-info
data:
  METADATA_NAME: ${METADATA_NAME}
  METADATA_UID: ${METADATA_UID}
EOF
fi

# -------------------------------------------------------------------------------------------------------------------
# Setup and configure the required addons
# -------------------------------------------------------------------------------------------------------------------

if [ "$(echo $REQUIRED_ADDONS_JSON | jq length)" -ne 0 ]; then
  divider && echo -e "$INFO [INFO] Installing and setting up addons:"
fi

for EACH_ADDON in $(echo $REQUIRED_ADDONS_JSON | jq -r '. | keys[]'); do
  divider
  case ${EACH_ADDON} in
  postgres)
    echo -e "$INFO [INFO] Releasing postgres in the '$NAMESPACE' namespace...\n"
    if ! $SCRIPT_DIR/release-psql.sh -n "$NAMESPACE"; then
      update_conditions "Failed to release PostgreSQL in the '$NAMESPACE' namespace" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_ADDONS_LIST+=($EACH_ADDON)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released PostgresSQL in the '$NAMESPACE' namespace"
      update_addon_status "$EACH_ADDON" "true" "true"
    fi # release-psql.sh
    ;;

  elasticSearch)
    echo -e "$INFO [INFO] Setting up elastic search operator and elastic search instance in the '$NAMESPACE' namespace..."
    if ! $SCRIPT_DIR/../../EventEnabledInsurance/setup-elastic-search.sh -n "$NAMESPACE" -e "$NAMESPACE"; then
      update_conditions "Failed to install and configure elastic search in the '$NAMESPACE' namespace" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_ADDONS_LIST+=($EACH_ADDON)
    else
      echo -e "\n$TICK [INFO] Successfully installed and configured elastic search in the '$NAMESPACE' namespace"
      update_addon_status "$EACH_ADDON" "true" "true"
    fi # setup-elastic-search.sh
    ;;

  ocpPipelines)
    echo -e "$INFO [INFO] Installing OCP pipelines...\n"
    if ! $SCRIPT_DIR/install-ocp-pipeline.sh; then
      update_conditions "Failed to install OCP pipelines" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_ADDONS_LIST+=($EACH_ADDON)
    else
      echo -e "$TICK [SUCCESS] Successfully installed OCP pipelines"
      update_addon_status "$EACH_ADDON" "true" "false"
    fi # install-ocp-pipeline.sh

    divider && echo -e "$INFO [INFO] Configuring secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace\n"
    if ! $SCRIPT_DIR/configure-ocp-pipeline.sh -n "$NAMESPACE"; then
      update_conditions "Failed to create secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_ADDONS_LIST+=($EACH_ADDON)
    else
      echo -e "$TICK [SUCCESS] Successfully configured secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace"
      update_addon_status "$EACH_ADDON" "true" "true"
    fi # configure-ocp-pipeline.sh
    ;;

  *)
    echo -e "$CROSS ERROR: Unknown addon type: ${EACH_ADDON}" 1>&2
    divider
    exit 1
    ;;
  esac
done

#-------------------------------------------------------------------------------------------------------------------
# Check if tracing is enabled in the selected/required products
#-------------------------------------------------------------------------------------------------------------------

[[ "$(echo $REQUIRED_PRODUCTS_JSON | jq '.tracing?')" == "true" ]] && TRACING_ENABLED=true || TRACING_ENABLED=false
divider && echo -e "$INFO [INFO] Tracing enabled: '$TRACING_ENABLED'"

#-------------------------------------------------------------------------------------------------------------------
# Install the selected/required products
#-------------------------------------------------------------------------------------------------------------------

divider && echo -e "$INFO Starting products installation..." && divider
for EACH_PRODUCT in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '. | keys[]'); do
  ECHO_LINE="in the '$NAMESPACE' namespace with the name"

  case ${EACH_PRODUCT} in
  mq)
    # if to enable or disable tracing while releasing MQ
    if [[ "$TRACING_ENABLED" == "true" ]]; then
      RELEASE_MQ_PARAMS="-n $NAMESPACE -z $NAMESPACE -r $MQ_RELEASE_NAME -t"
    else
      RELEASE_MQ_PARAMS="-n $NAMESPACE -r $MQ_RELEASE_NAME"
    fi

    echo -e "$INFO [INFO] Releasing MQ $ECHO_LINE '$MQ_RELEASE_NAME' with release parameters as '$RELEASE_APIC_PARAMS'...\n"

    if ! $SCRIPT_DIR/release-mq.sh $RELEASE_MQ_PARAMS; then
      update_conditions "Failed to release MQ $ECHO_LINE '$MQ_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released MQ $ECHO_LINE '$MQ_RELEASE_NAME'"
      update_product_status "$MQ_RELEASE_NAME" "$EACH_PRODUCT" "true" "true"
    fi # release-mq.sh
    divider
    ;;

  aceDesigner)
    echo -e "$INFO [INFO] Releasing ACE Designer $ECHO_LINE '$ACE_DESIGNER_RELEASE_NAME'...\n"
    if ! $SCRIPT_DIR/release-ace-designer.sh -n "$NAMESPACE" -r "$ACE_DESIGNER_RELEASE_NAME" -s "$BLOCK_STORAGE_CLASS"; then
      update_conditions "Failed to release ACE Designer $ECHO_LINE '$ACE_DESIGNER_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [INFO] Successfully released ACE Designer $ECHO_LINE '$ACE_DESIGNER_RELEASE_NAME'"
      update_product_status "$ACE_DESIGNER_RELEASE_NAME" "$EACH_PRODUCT" "true" "true"
    fi # release-ace-designer.sh
    divider
    ;;

  assetRepo)
    echo -e "$INFO [INFO] Releasing Asset Repository $ECHO_LINE '$ASSET_REPOSITORY_RELEASE_NAME'...\n"
    if ! $SCRIPT_DIR/release-ar.sh -n "$NAMESPACE" -r "$ASSET_REPOSITORY_RELEASE_NAME" -a "$FILE_STORAGE_CLASS" -c "$BLOCK_STORAGE_CLASS"; then
      update_conditions "Failed to release Asset Repository $ECHO_LINE '$ASSET_REPOSITORY_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released Asset Repository $ECHO_LINE '$ASSET_REPOSITORY_RELEASE_NAME'"
      update_product_status "$ASSET_REPOSITORY_RELEASE_NAME" "$EACH_PRODUCT" "true" "false"
    fi # release-ar.sh
    divider
    ;;

  aceDashboard)
    echo -e "$INFO [INFO] Releasing ACE dashboard $ECHO_LINE '$ACE_DASHBOARD_RELEASE_NAME'...\n"
    if ! $SCRIPT_DIR/release-ace-dashboard.sh -n "$NAMESPACE" -r "$ACE_DASHBOARD_RELEASE_NAME" -s "$FILE_STORAGE_CLASS"; then
      update_conditions "Failed to release ACE dashboard $ECHO_LINE '$ACE_DASHBOARD_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released ACE dashboard $ECHO_LINE '$ACE_DASHBOARD_RELEASE_NAME'"
      update_product_status "$ACE_DASHBOARD_RELEASE_NAME" "$EACH_PRODUCT" "true" "true"
    fi # release-ace-dashboard.sh
    divider
    ;;

  apic)
    # if no config value passed for APIC in the input configuration, set to default values else take from passed apic configuration
    export PORG_ADMIN_EMAIL=$(echo ${APIC_CONFIGURATION} | jq -r '. | if has("emailAddress") then .emailAddress else "'$DEFAULT_APIC_EMAIL_ADDRESS'" end')
    export MAIL_SERVER_HOST=$(echo ${APIC_CONFIGURATION} | jq -r '. | if has("mailServerHost") then .mailServerHost else "'$DEFAULT_APIC_MAIL_SERVER_HOST'" end')
    export MAIL_SERVER_PORT=$(echo ${APIC_CONFIGURATION} | jq -r '. | if has("mailServerPort") then .mailServerPort else "'$DEFAULT_APIC_MAIL_SERVER_PORT'" end')
    export MAIL_SERVER_USERNAME=$(echo ${APIC_CONFIGURATION} | jq -r '. | if has("mailServerUsername") then .mailServerUsername else "'$DEFAULT_APIC_MAIL_SERVER_USERNAME'" end')
    export MAIL_SERVER_PASSWORD=$(echo ${APIC_CONFIGURATION} | jq -r '. | if has("mailServerPassword") then .mailServerPassword else "'$DEFAULT_APIC_MAIL_SERVER_PASSWORD'" end')

    # check if to enable or disable tracing while releasing APIC
    if [[ "$TRACING_ENABLED" == "true" ]]; then
      RELEASE_APIC_PARAMS="-n $NAMESPACE -r $APIC_RELEASE_NAME -t"
    else
      RELEASE_APIC_PARAMS="-n $NAMESPACE -r $APIC_RELEASE_NAME"
    fi

    echo -e "$INFO [INFO] Releasing APIC $ECHO_LINE '$APIC_RELEASE_NAME' with release parameters as '$RELEASE_APIC_PARAMS'...\n"

    if ! $SCRIPT_DIR/release-apic.sh $RELEASE_APIC_PARAMS; then
      update_conditions "Failed to release APIC $ECHO_LINE '$APIC_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released APIC $ECHO_LINE '$APIC_RELEASE_NAME'"
      update_product_status "$APIC_RELEASE_NAME" "$EACH_PRODUCT" "true" "false"
    fi # release-apic.sh
    divider
    ;;

  eventStreams)
    echo -e "$INFO [INFO] Releasing Event Streams $ECHO_LINE '$EVENT_STREAM_RELEASE_NAME'...\n"
    if ! $SCRIPT_DIR/release-es.sh -n "$NAMESPACE" -r "$EVENT_STREAM_RELEASE_NAME"; then
      update_conditions "Failed to release $ECHO_LINE '$EVENT_STREAM_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released event streams $ECHO_LINE '$EVENT_STREAM_RELEASE_NAME'"
      update_product_status "$EVENT_STREAM_RELEASE_NAME" "$EACH_PRODUCT" "true" "true"
    fi # release-es.sh
    divider
    ;;

  tracing)
    echo -e "$INFO [INFO] Releasing tracing $ECHO_LINE '$TRACING_RELEASE_NAME'...\n"
    if ! $SCRIPT_DIR/release-tracing.sh -n "$NAMESPACE" -r "$TRACING_RELEASE_NAME" -b "$BLOCK_STORAGE_CLASS" -f "$FILE_STORAGE_CLASS"; then
      update_conditions "Failed to release Tracing $ECHO_LINE '$TRACING_RELEASE_NAME'" "Releasing"
      update_phase "Failed"
      FAILED_INSTALL_PRODUCTS_LIST+=($EACH_PRODUCT)
    else
      echo -e "\n$TICK [SUCCESS] Successfully released Tracing $ECHO_LINE '$TRACING_RELEASE_NAME'"
      update_product_status "$TRACING_RELEASE_NAME" "$EACH_PRODUCT" "true" "false"
    fi # release-tracing.sh
    divider
    ;;

  *)
    divider && echo -e "$CROSS ERROR: Unknown product type: ${EACH_PRODUCT}" 1>&2
    divider
    exit 1
    ;;
  esac
done

#-------------------------------------------------------------------------------------------------------------------
# Configure APIC if APIC is amongst selected product. Tracing registration is a pre-req for this step.
#-------------------------------------------------------------------------------------------------------------------

if [[ "$(echo $REQUIRED_PRODUCTS_JSON | jq '.apic?')" == "true" ]]; then
  echo -e "$INFO [INFO] Configuring APIC in the '$NAMESPACE' namespace...\n"
  if ! $SCRIPT_DIR/configure-apic-v10.sh -n "$NAMESPACE" -r "$APIC_RELEASE_NAME"; then
    update_conditions "Failed to configure APIC in the '$NAMESPACE' namespace" "Releasing"
    update_phase "Failed"
    update_product_status "$APIC_RELEASE_NAME" "apic" "true" "false"
    FAILED_INSTALL_PRODUCTS_LIST+=(apic)
  else
    echo -e "$TICK [SUCCESS] Successfully configured APIC in the '$NAMESPACE' namespace"
    update_product_status "$APIC_RELEASE_NAME" "apic" "true" "true"
  fi # configure-apic-v10.sh
  divider
fi

#-------------------------------------------------------------------------------------------------------------------
# If asset repository is enabled, create Asset Repository remote
#-------------------------------------------------------------------------------------------------------------------

if [[ "$(echo $REQUIRED_PRODUCTS_JSON | jq '.assetRepo?')" == "true" ]]; then
  echo -e "$INFO [INFO] Creating Asset Repository remote in the '$NAMESPACE' namespace with the name '$ASSET_REPOSITORY_RELEASE_NAME'...\n"
  if ! $SCRIPT_DIR/ar_remote_create.sh -r "$ASSET_REPOSITORY_RELEASE_NAME" -n "$NAMESPACE" -o; then
    update_conditions "Failed to create Asset Repository remote in the '$NAMESPACE' namespace with the name '$ASSET_REPOSITORY_RELEASE_NAME'" "Releasing"
    update_phase "Failed"
    update_product_status "$ASSET_REPOSITORY_RELEASE_NAME" "assetRepo" "true" "false"
    FAILED_INSTALL_PRODUCTS_LIST+=(assetRepo)
  else
    echo -e "\n$TICK [SUCCESS] Successfully created Asset Repository remote in the '$NAMESPACE' namespace with the name '$ASSET_REPOSITORY_RELEASE_NAME'"
    update_product_status "$ASSET_REPOSITORY_RELEASE_NAME" "assetRepo" "true" "true"
  fi # ar_remote_create.sh
  divider
fi

#-------------------------------------------------------------------------------------------------------------------
# Setup the required demos
#-------------------------------------------------------------------------------------------------------------------

echo -e "$INFO [INFO] Starting demos setup..." && divider
for EACH_DEMO in $(echo $REQUIRED_DEMOS_JSON | jq -r '. | keys[]'); do
  case $EACH_DEMO in
  cognitiveCarRepair)
    set_up_demos "$EACH_DEMO" "Cognitive Car Repair" "${#COGNITIVE_CAR_REPAIR_PRODUCTS_LIST[@]}" "${COGNITIVE_CAR_REPAIR_PRODUCTS_LIST[@]}" "${#COGNITIVE_CAR_REPAIR_ADDONS_LIST[@]}" "${COGNITIVE_CAR_REPAIR_ADDONS_LIST[@]}"
    divider
    ;;

  eventEnabledInsurance)
    echo -e "$INFO [INFO] Starting the setup of the event enabled insurance demo"
    echo -e "\n$INFO [INFO] Checking if all addons are installed and configured for the event enabled insurance demo"
    check_current_status "$EACH_DEMO" "addons" "${EVENT_ENABLED_INSURANCE_ADDONS_LIST[@]}"
    ADDONS_CONFIGURED=$DEMO_CONFIGURED
    echo -e "\n$INFO [INFO] Checking if all products are installed and setup for the event enabled insurance demo"
    check_current_status "$EACH_DEMO" "products" "${EVENT_ENABLED_INSURANCE_PRODUCTS_LIST[@]}"
    PRODUCTS_CONFIGURED=$DEMO_CONFIGURED
    if [[ "$ADDONS_CONFIGURED" == "true" && "$PRODUCTS_CONFIGURED" == "true" ]]; then
      # if all addon/products are installed and configured correctly, set installed to true, but ready to false as configuration still left and then run the prereqs
      update_demo_status "$EACH_DEMO" "true" "false"

      divider && echo -e "$INFO [INFO] Setting up prereqs for Event Enabled Insurance demo in the '$NAMESPACE' namespace" && divider
      # setup the prereqs for event enabled insurance demo
      if ! $SCRIPT_DIR/../../EventEnabledInsurance/prereqs.sh -n "$NAMESPACE" -b "$SAMPLES_REPO_BRANCH" -e "$NAMESPACE" -p "$NAMESPACE" -f "$FILE_STORAGE_CLASS" -g "$BLOCK_STORAGE_CLASS" -o; then
        echo -e "$CROSS [ERROR] Failed to run event enabled insurance prereqs script\n"
        divider && echo -e "$CROSS [ERROR] Event Enabled Insurance demo did not setup correctly. $CROSS"
        update_conditions "Failed to run event enabled insurance prereqs script in the '$NAMESPACE' namespace" "Prereqs"
        update_phase "Failed"
        update_demo_status "$EACH_DEMO" "" "false"
        FAILED_INSTALL_DEMOS_LIST+=($EACH_DEMO)
      else
        echo -e "$TICK $ALL_DONE [SUCCESS] Event Enabled Insurance demo setup completed successfully in the '$NAMESPACE' namespace. $ALL_DONE $TICK"
        update_demo_status "$EACH_DEMO" "" "true"
      fi # EventEnabledInsurance/prereqs.sh
    else
      # If one or more products failed to setup/configure, demo is not ready to use, set installed and ready to false
      update_demo_status "$EACH_DEMO" "false" "false"
    fi
    divider
    ;;

  drivewayDentDeletion)
    echo -e "$INFO [INFO] Setting up the driveway dent deletion demo...\n"
    echo -e "$INFO [INFO] Checking if all addons are installed and setup for the driveway dent deletion demo\n"
    check_current_status "$EACH_DEMO" "addons" "${DRIVEWAY_DENT_DELETION_ADDONS_LIST[@]}"
    ADDONS_CONFIGURED=$DEMO_CONFIGURED
    echo -e "\n$INFO [INFO] Checking if all products are installed and setup for the driveway dent deletion demo\n"
    check_current_status "$EACH_DEMO" "products" "${DRIVEWAY_DENT_DELETION_PRODUCTS_LIST[@]}"
    PRODUCTS_CONFIGURED=$DEMO_CONFIGURED
    if [[ "$ADDONS_CONFIGURED" == "true" && "$PRODUCTS_CONFIGURED" == "true" ]]; then
      # if all addon/products are installed and configured correctly, set installed to true, but ready to false as configuration still left
      update_demo_status "$EACH_DEMO" "true" "false"
      divider && echo -e "$INFO [INFO] Setting up prereqs for driveway dent deletion demo in the '$NAMESPACE' namespace" && divider
      # setup the prereqs for driveway dent deletion demo
      if ! $SCRIPT_DIR/../../DrivewayDentDeletion/Operators/prereqs.sh -n "$NAMESPACE" -p "$NAMESPACE" -o; then
        echo -e "\n$CROSS [ERROR] Failed to run driveway dent deletion prereqs script"
        divider && echo -e "$CROSS [ERROR] Driveway Dent Deletion demo did not setup correctly. $CROSS"
        update_conditions "Failed to run driveway dent deletion prereqs script in the '$NAMESPACE' namespace" "Prereqs"
        update_phase "Failed"
        update_demo_status "$EACH_DEMO" "" "false"
        FAILED_INSTALL_DEMOS_LIST+=($EACH_DEMO)
      else
        echo -e "$TICK $ALL_DONE [SUCCESS] Driveway Dent Deletion demo setup completed successfully in the '$NAMESPACE' namespace. $ALL_DONE $TICK"
        update_demo_status "$EACH_DEMO" "" "true"
      fi # DrivewayDentDeletion/Operators/prereqs.sh
    else
      # If one or more products failed to setup/configure, demo is not ready to use, set installed and ready to false
      update_demo_status "$EACH_DEMO" "false" "false"
    fi
    divider
    ;;

  mappingAssist)
    set_up_demos "$EACH_DEMO" "Mapping Assist" "${#MAPPING_ASSIST_PRODUCTS_LIST[@]}" "${MAPPING_ASSIST_PRODUCTS_LIST[@]}" "${#MAPPING_ASSIST_ADDONS_LIST[@]}" "${MAPPING_ASSIST_ADDONS_LIST[@]}"
    divider
    ;;

  weatherChatbot)
    set_up_demos "$EACH_DEMO" "Weather Chatbot" "${#ACE_WEATHER_CHATBOT_PRODUCTS_LIST[@]}" "${ACE_WEATHER_CHATBOT_PRODUCTS_LIST[@]}" "${#ACE_WEATHER_CHATBOT_ADDONS_LIST[@]}" "${ACE_WEATHER_CHATBOT_ADDONS_LIST[@]}"
    divider
    ;;

  *)
    divider && echo -e "$CROSS ERROR: Unknown demo type: ${EACH_DEMO}" 1>&2
    divider
    exit 1
    ;;
  esac
done

#-------------------------------------------------------------------------------------------------------------------
# Print the names of the addons that failed to install if any
#-------------------------------------------------------------------------------------------------------------------

if [[ ${#FAILED_INSTALL_ADDONS_LIST[@]} -ne 0 ]]; then
  # Get only unique values
  FAILED_INSTALL_ADDONS_LIST=($(printf "%s\n" "${FAILED_INSTALL_ADDONS_LIST[@]}" | sort -u | tr '\n' ' '))
  echo -e "$CROSS [ERROR] The following addons failed to install and/or setup successfully in the '$NAMESPACE' namespace:\n"
  listCounter=1
  for eachFailedAddon in ${FAILED_INSTALL_ADDONS_LIST[@]}; do
    echo "$listCounter. $eachFailedAddon"
    listCounter=$((listCounter + 1))
  done
  divider
fi

#-------------------------------------------------------------------------------------------------------------------
# Print the names of the products that failed to install if any
#-------------------------------------------------------------------------------------------------------------------

if [[ ${#FAILED_INSTALL_PRODUCTS_LIST[@]} -ne 0 ]]; then
  # Get only unique values
  FAILED_INSTALL_PRODUCTS_LIST=($(printf "%s\n" "${FAILED_INSTALL_PRODUCTS_LIST[@]}" | sort -u | tr '\n' ' '))
  echo -e "$CROSS [ERROR] The following products failed to install and/or setup successfully in the '$NAMESPACE' namespace:\n"
  listCounter=1
  for eachFailedProduct in ${FAILED_INSTALL_PRODUCTS_LIST[@]}; do
    echo "$listCounter. $eachFailedProduct"
    listCounter=$((listCounter + 1))
  done
  divider
fi

#-------------------------------------------------------------------------------------------------------------------
# Print the names of the demos that failed to setup if any
#-------------------------------------------------------------------------------------------------------------------

if [[ ${#FAILED_INSTALL_DEMOS_LIST[@]} -ne 0 ]]; then
  # Get only unique values
  FAILED_INSTALL_DEMOS_LIST=($(printf "%s\n" "${FAILED_INSTALL_DEMOS_LIST[@]}" | sort -u | tr '\n' ' '))
  echo -e "$CROSS [ERROR] The following demos failed to install and/or setup successfully in the '$NAMESPACE' namespace:\n"
  listCounter=1
  for eachFailedDemo in ${FAILED_INSTALL_DEMOS_LIST[@]}; do
    echo "$listCounter. $eachFailedDemo"
    listCounter=$((listCounter + 1))
  done
  divider
fi

#-------------------------------------------------------------------------------------------------------------------
# Exit only if any one of the previous step(s) (addons/products/demos) changed the phase to Failed
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && echo -e "$INFO [DEBUG] Status after all installations:\n" && echo $STATUS | jq .
check_phase_and_exit_on_failed

#-------------------------------------------------------------------------------------------------------------------
# Calculate total time taken for all installation
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo -e "$INFO [DEBUG] The installation and setup for the selected addons, products and demos took $(($SECONDS / 60 / 60 % 24)) hours $(($SECONDS / 60 % 60)) minutes and $(($SECONDS % 60)) seconds." && divider

#-------------------------------------------------------------------------------------------------------------------
# Change final status to Running at end of installation
#-------------------------------------------------------------------------------------------------------------------

echo -e "$TICK [SUCCESS] Successfully installed all selected addons, products and demos. Changing the overall status to 'Running'"
update_phase "Running"
$DEBUG && echo -e "$INFO [DEBUG] Final status:\n" && echo $STATUS | jq .
divider
