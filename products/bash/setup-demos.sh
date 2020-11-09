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

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -i input.yaml -o output.yaml"
  divider
  exit 1
}

while getopts "i:o:" opt; do
  case ${opt} in
  i)
    INPUT_YAML_FILE="$OPTARG"
    ;;
  o)
    OUTPUT_YAML_FILE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
SCRIPT_DIR=$(dirname $0)
DEBUG=true
FAILURE_CODE=1
SUCCESS_CODE=0
CONDITION_ELEMENT_OBJECT='{"lastTransitionTime":"","message":"","reason":"","status":"","type":""}'
NAMESPACE_OBJECT='{"name":""}'
TRACING_ENABLED=false
APIC_ENABLED=false

declare -a ARRAY_FOR_FAILED_INSTALL_PRODUCTS
declare -a ARRAY_FOR_FAILED_INSTALL_ADDONS

function product_set_defaults() {
  PRODUCT_JSON=${1}
  PRODUCT_TYPE=$(echo ${PRODUCT_JSON} | jq -r '.type')
  case ${PRODUCT_TYPE} in
  aceDashboard) DEFAULTS='{"name":"ace-dashboard-demo"}' ;;
  aceDesigner) DEFAULTS='{"name":"ace-designer-demo"}' ;;
  apic) DEFAULTS='{"name":"ademo","emailAddress":"your@email.address","mailServerHost":"smtp.mailtrap.io","mailServerPassword":"<your-password>","mailServerPort":2525,"mailServerUsername":"<your-username>"}' ;;
  assetRepo) DEFAULTS='{"name":"ar-demo"}' ;;
  eventStreams) DEFAULTS='{"name":"es-demo"}' ;;
  mq) DEFAULTS='{"name":"mq-demo"}' ;;
  navigator) DEFAULTS='{"name":"navigator"}' ;;
  tracing) DEFAULTS='{"name":"tracing-demo"}' ;;
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

function product_fixup_namespace() {
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

function merge_product() {
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

function merge_addon() {
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

function update_conditions() {
  MESSAGE=${1}
  REASON=${2}            # command type
  CONDITION_TYPE="Error" # for the type in conditions
  TIMESTAMP=$(date -u +%FT%T.%Z)

  echo -e "\n$cross [ERROR] $MESSAGE"
  $DEBUG && echo -e "\n$info update_conditions(): reason($REASON) - conditionType($CONDITION_TYPE) - timestamp($TIMESTAMP)"

  # update condition array
  CONDITION_TO_ADD=$(echo $CONDITION_ELEMENT_OBJECT | jq -r '.message="'"$MESSAGE"'" | .status="True" | .type="'$CONDITION_TYPE'" | .lastTransitionTime="'$TIMESTAMP'" | .reason="'$REASON'" ')
  # add condition to condition array
  STATUS=$(echo $STATUS | jq -c '.conditions += ['"${CONDITION_TO_ADD}"']')
  $DEBUG && echo -e "\n$info [INFO] Printing the status conditions array" && echo $STATUS | jq -r '.conditions'
}

function update_phase() {
  PHASE=${1} # Pending, Running or Failed

  $DEBUG && divider && echo -e "$info [INFO] update_phase(): phase($PHASE)"

  STATUS=$(echo $STATUS | jq -c '.phase="'$PHASE'"')
}

function check_phase_and_exit_on_failed() {

  CURRENT_PHASE=$(echo $STATUS | jq -r '.phase')

  # if the current phase is failed, then exit status (case insensitive checking)
  if echo $CURRENT_PHASE | grep -iqF failed; then
    divider && echo -e "$info [INFO] Current installation phase is '$CURRENT_PHASE', exiting now." && divider
    exit 1
  else
    $DEBUG && divider && echo -e "$info [INFO] Current installation phase is '$CURRENT_PHASE', continuing the installation..."
  fi
}

#-------------------------------------------------------------------------------------------------------------------
# Validate the parameters passed in
#-------------------------------------------------------------------------------------------------------------------
missingParams="false"
if [[ -z "${INPUT_YAML_FILE// /}" ]]; then
  echo -e "$cross ERROR: INPUT_YAML_FILE is empty. Please provide a value for '-i' parameter." 1>&2
  missingParams="true"
fi

if [[ -z "${OUTPUT_YAML_FILE// /}" ]]; then
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
divider && echo -e "$info Script directory: '$SCRIPT_DIR'"
echo -e "$info Input yaml file: '$INPUT_YAML_FILE'"
echo -e "$info Output yaml file : '$OUTPUT_YAML_FILE'\n"

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
$DEBUG && echo "\n[DEBUG] Get storage classes and branch from $INPUT_YAML_FILE"
GENERAL=$(echo $JSON | jq -r .spec.general)
BLOCK_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.block | if has("class") then .class else "cp4i-block-performance" end')
FILE_STORAGE_CLASS=$(echo $GENERAL | jq -r '.storage.file | if has("class") then .class else "ibmc-file-gold-gid" end')
SAMPLES_REPO_BRANCH=$(echo $GENERAL | jq -r 'if has("samplesRepoBranch") then .samplesRepoBranch else "main" end')
NAMESPACE=$(echo $JSON | jq -r .metadata.namespace)
REQUIRED_DEMOS_JSON=$(echo $JSON | jq -c '.spec | if has("demos") then .demos else {} end')
REQUIRED_PRODUCTS_JSON=$(echo $JSON | jq -c '.spec | if has("products") then .products else [] end')
REQUIRED_ADDONS_JSON=$(echo $JSON | jq -c '.spec | if has("addons") then .addons else [] end')
STATUS=$(echo $JSON | jq -r .status)

echo -e "\n$info Block storage class: '$BLOCK_STORAGE_CLASS'"
echo -e "$info File storage class: '$FILE_STORAGE_CLASS'"
echo -e "$info Samples repo branch: '$SAMPLES_REPO_BRANCH'"
echo -e "$info Namespace: '$NAMESPACE'" && divider

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
# Change status phase to Pending as installation starting
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider && echo -e "$info [INFO] Changing the status to 'Pending' as installation is starting..."
update_phase "Pending"

#-------------------------------------------------------------------------------------------------------------------
# Check if the namespace  and the secret exists
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo -e "$info [INFO] Check if the '$NAMESPACE' namespace and the secret 'ibm-entitlement-key' exists...\n"

# add namespace to status if exists
oc get project $NAMESPACE 2>&1 >/dev/null
if [ $? -ne 0 ]; then
  update_conditions "Namespace '$NAMESPACE' does not exist" "Getting"
  update_phase "Failed"
else
  echo -e "$tick [SUCCESS] Namespace '$NAMESPACE' exists"
  NAMESPACE_TO_ADD=$(echo $NAMESPACE_OBJECT | jq -r '.name="'$NAMESPACE'" ')
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
  echo -e "$tick [SUCCESS] Secret 'ibm-entitlement-key' exists in the '$NAMESPACE' namespace"
fi

check_phase_and_exit_on_failed

#-------------------------------------------------------------------------------------------------------------------
# Add the required addons
#-------------------------------------------------------------------------------------------------------------------
divider && echo -e "$info [INFO] Installing and setting up addons:"
for row in $(echo "${REQUIRED_ADDONS_JSON}" | jq -r '.[] | select(.enabled == true ) | @base64'); do
  divider
  ADDON_JSON=$(echo ${row} | base64 --decode)
  $DEBUG && echo ${ADDON_JSON} | jq . && echo ""
  ADDON_TYPE=$(echo ${ADDON_JSON} | jq -r '.type')

  # case ${ADDON_TYPE} in

  # postgres)
  #   echo -e "$info [INFO] Releasing postgres...\n"
  #   if ! $SCRIPT_DIR/release-psql.sh -n $NAMESPACE; then
  #     update_conditions "Failed to release PostgreSQL in the '$NAMESPACE' namespace" "Releasing"
  #     update_phase "Failed"
  #     ARRAY_FOR_FAILED_INSTALL_ADDONS+=($ADDON_TYPE)
  #   else
  #     echo -e "\n$tick [SUCCESS] Successfully released PostgresSQL in the '$NAMESPACE' namespace"
  #   fi # release-psql.sh
  #   ;;

  # elasticSearch)
  #   echo -e "$info [INFO] Setting up elastic search operator and elastic search instance in the '$NAMESPACE' namespace..."
  #   if ! $SCRIPT_DIR/../../EventEnabledInsurance/setup-elastic-search.sh -n ${NAMESPACE} -e ${NAMESPACE}; then
  #     update_conditions "Failed to install and configure elastic search in the '$NAMESPACE' namespace" "Releasing"
  #     update_phase "Failed"
  #     ARRAY_FOR_FAILED_INSTALL_ADDONS+=($ADDON_TYPE)
  #   else
  #     echo -e "\n$tick [INFO] Successfully installed and configured elastic search in the '$NAMESPACE' namespace"
  #   fi # setup-elastic-search.sh
  #   ;;

  # ocpPipelines)
  #   echo -e "$info [INFO] Installing OCP pipelines...\n"
  #   if ! ${SCRIPT_DIR}/install-ocp-pipeline.sh; then
  #     update_conditions "Failed to install OCP pipelines" "Releasing"
  #     update_phase "Failed"
  #     ARRAY_FOR_FAILED_INSTALL_ADDONS+=($ADDON_TYPE)
  #   else
  #     echo -e "$tick [SUCCESS] Successfully installed OCP pipelines" && divider
  #   fi # install-ocp-pipeline.sh

  #   echo -e "$info [INFO] Configuring secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace\n"
  #   if ! ${SCRIPT_DIR}/configure-ocp-pipeline.sh -n ${NAMESPACE}; then
  #     update_conditions "Failed to create secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace" "Releasing"
  #     update_phase "Failed"
  #     ARRAY_FOR_FAILED_INSTALL_ADDONS+=($ADDON_TYPE)
  #   else
  #     echo -e "$tick [SUCCESS] Successfully configured secrets and permissions related to ocp pipelines in the '$NAMESPACE' namespace"
  #   fi # configure-ocp-pipeline.sh
  #   ;;

  # *)
  #   echo -e "$cross ERROR: Unknown addon type: ${ADDON_TYPE}" 1>&2
  #   divider
  #   exit 1
  #   ;;
  # esac
done

#-------------------------------------------------------------------------------------------------------------------
# Display all the namespaces
#-------------------------------------------------------------------------------------------------------------------
$DEBUG && divider && echo -e "$info Namespaces:"
for eachNamespace in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '[ .[] | select(.enabled == true ) | .namespace ] | unique | .[]'); do
  $DEBUG && echo "$eachNamespace"
done

#-------------------------------------------------------------------------------------------------------------------
# Check if tracing is enabled in the selected/required products
#-------------------------------------------------------------------------------------------------------------------

divider && echo -e "$info [INFO] Checking if Tracing is enabled...\n"

if [[ ! "$(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '.[] | select(.enabled == true and .type == "tracing")')" == "" ]]; then
  TRACING_ENABLED=true
fi

echo -e "$info [INFO] Tracing enabled: '$TRACING_ENABLED'..."

#-------------------------------------------------------------------------------------------------------------------
# Install the selected/required products
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo -e "$info Starting selected products' installation..."
for eachProduct in $(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '.[] | select(.enabled == true ) | @base64'); do
  EACH_PRODUCT_JSON=$(echo ${eachProduct} | base64 --decode)
  $DEBUG && echo $EACH_PRODUCT_JSON | jq .

  EACH_PRODUCT_TYPE=$(echo ${EACH_PRODUCT_JSON} | jq -r '.type')
  EACH_PRODUCT_NAME=$(echo ${EACH_PRODUCT_JSON} | jq -r '.name')
  ECHO_LINE="in the '$NAMESPACE' namespace with the name '$EACH_PRODUCT_NAME'"

  case ${EACH_PRODUCT_TYPE} in

  mq)
    echo -e "$info [INFO] Releasing MQ $ECHO_LINE...\n"
    if [[ "$TRACING_ENABLED" == "true" ]]; then
      RELEASE_MQ_PARAMS="-n $NAMESPACE -z $NAMESPACE -r $EACH_PRODUCT_NAME -t"
    else
      RELEASE_MQ_PARAMS="-n $NAMESPACE -r $EACH_PRODUCT_NAME"
    fi

    if ! $SCRIPT_DIR/release-mq.sh $RELEASE_MQ_PARAMS; then
      update_conditions "Failed to release MQ $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "\n$tick [SUCCESS] Successfully released MQ $ECHO_LINE"
    fi # release-mq.sh
    divider
    ;;

  aceDesigner)
    echo -e "\n$info [INFO] Releasing ACE Designer $ECHO_LINE..."
    if ! $SCRIPT_DIR/release-ace-designer.sh -n $NAMESPACE -r $EACH_PRODUCT_NAME; then
      update_conditions "Failed to release ACE Designer $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "\n$tick [INFO] Successfully released ACE Designer $ECHO_LINE"
    fi # release-ace-designer.sh
    divider
    ;;

  assetRepo)
    # Get APIC release name for configuring APIC
    AR_REMOTE_NAME=$EACH_PRODUCT_NAME
    echo -e "\n$info [INFO] Releasing Asset Repository $ECHO_LINE...\n"
    if ! $SCRIPT_DIR/release-ar.sh -n $NAMESPACE -r $EACH_PRODUCT_NAME; then
      update_conditions "Failed to release Asset Repository $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully released Asset Repository $ECHO_LINE" && divider
    fi # release-ar.sh
    divider
    ;;

  aceDashboard)
    echo -e "\n$info [INFO] Releasing ACE dashboard $ECHO_LINE...\n"
    if ! $SCRIPT_DIR/release-ace-dashboard.sh -n $NAMESPACE -r $EACH_PRODUCT_NAME; then
      update_conditions "Failed to release ACE dashboard $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully released ACE dashboard $ECHO_LINE" && divider
    fi # release-ace-dashboard.sh
    divider
    ;;

  apic)
    echo -e "\n$info [INFO] Releasing APIC $ECHO_LINE...\n"

    APIC_RELEASE_NAME=$EACH_PRODUCT_NAME

    export PORG_ADMIN_EMAIL=$(echo ${EACH_PRODUCT_JSON} | jq -r '.emailAddress')
    export MAIL_SERVER_HOST=$(echo ${EACH_PRODUCT_JSON} | jq -r '.mailServerHost')
    export MAIL_SERVER_PORT=$(echo ${EACH_PRODUCT_JSON} | jq -r '.mailServerPort')
    export MAIL_SERVER_USERNAME=$(echo ${EACH_PRODUCT_JSON} | jq -r '.mailServerUsername')
    export MAIL_SERVER_PASSWORD=$(echo ${EACH_PRODUCT_JSON} | jq -r '.mailServerPassword')

    if [[ "$TRACING_ENABLED" == "true" ]]; then
      RELEASE_APIC_PARAMS="-n $NAMESPACE -r $EACH_PRODUCT_NAME -t"
    else
      RELEASE_APIC_PARAMS="-n $NAMESPACE -r $EACH_PRODUCT_NAME"
    fi

    if ! $SCRIPT_DIR/release-apic.sh $RELEASE_APIC_PARAMS; then
      update_conditions "Failed to release APIC $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully released APIC $ECHO_LINE" && divider
    fi # release-apic.sh
    divider
    ;;

  eventStreams)
    echo -e "\n$info [INFO] Releasing Event Streams $ECHO_LINE...\n"
    if ! $SCRIPT_DIR/release-es.sh -n $NAMESPACE -r $EACH_PRODUCT_NAME; then
      update_conditions "Failed to release $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully release $ECHO_LINE" && divider
    fi # release-es.sh
    divider
    ;;

  tracing)
    echo -e "\n$info [INFO] Releasing tracing $ECHO_LINE...\n"
    if ! $SCRIPT_DIR/release-tracing.sh -n $NAMESPACE -r $EACH_PRODUCT_NAME; then
      update_conditions "Failed to release Tracing $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully released Tracing $ECHO_LINE" && divider
    fi # release-tracing.sh

    echo -e "$info [INFO] Registering tracing $ECHO_LINE...\n"
    if ! $SCRIPT_DIR/register-tracing.sh -n $NAMESPACE; then
      update_conditions "Failed to register Tracing $ECHO_LINE" "Releasing"
      update_phase "Failed"
      ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=($EACH_PRODUCT_TYPE)
    else
      echo -e "$tick [SUCCESS] Successfully registered Tracing $ECHO_LINE"
    fi # release-tracing.sh
    ;;

  *)
    divider && echo -e "$cross ERROR: Unknown product type: ${EACH_PRODUCT_TYPE}" 1>&2
    divider
    exit 1
    ;;
  esac
done

#-------------------------------------------------------------------------------------------------------------------
# Configure APIC if APIC is amongst selected product
#-------------------------------------------------------------------------------------------------------------------

if [[ ! "$(echo "${REQUIRED_PRODUCTS_JSON}" | jq -r '.[] | select(.enabled == true and .type == "apic")')" == "" ]]; then
  divider && echo -e "$info [INFO] Configuring APIC in the '$NAMESPACE' namespace...\n"
  if ! $SCRIPT_DIR/configure-apic-v10.sh -n $NAMESPACE -r $APIC_RELEASE_NAME; then
    update_conditions "Failed to configure APIC in the '$NAMESPACE' namespace" "Releasing"
    update_phase "Failed"
    ARRAY_FOR_FAILED_INSTALL_PRODUCTS+=(apic)
  else
    echo -e "$tick [SUCCESS] Successfully configured APIC in the '$NAMESPACE' namespace"
    divider
  fi
fi

#-------------------------------------------------------------------------------------------------------------------
# Add the required demos
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo "Demos:"
for DEMO in $(echo $REQUIRED_DEMOS_JSON | jq -r 'to_entries[] | select( .value.enabled == true ) | .key'); do
  $DEBUG && echo $DEMO
done

#-------------------------------------------------------------------------------------------------------------------
# Print the names of the addons that failed to install
#-------------------------------------------------------------------------------------------------------------------

# print all failed addon names
if [[ ${#ARRAY_FOR_FAILED_INSTALL_ADDONS[@]} -ne 0 ]]; then
  # Get only unique values
  ARRAY_FOR_FAILED_INSTALL_ADDONS=$(echo ${ARRAY_FOR_FAILED_INSTALL_ADDONS[@]} | tr ' ' '\n' | sort -u | tr '\n' ' ')
  divider && echo -e "$info [INFO] The following addons failed to install and/or setup successfully:\n"
  listCounter=1
  for eachFailedAddon in ${ARRAY_FOR_FAILED_INSTALL_ADDONS[@]}; do
    echo "$listCounter. $eachFailedAddon"
    listCounter=$((listCounter + 1))
  done
fi

#-------------------------------------------------------------------------------------------------------------------
# Print the names of the products that failed to install
#-------------------------------------------------------------------------------------------------------------------

# print all failed product names
if [[ ${#ARRAY_FOR_FAILED_INSTALL_PRODUCTS[@]} -ne 0 ]]; then
  # Get only unique values
  ARRAY_FOR_FAILED_INSTALL_PRODUCTS=$(echo ${ARRAY_FOR_FAILED_INSTALL_PRODUCTS[@]} | tr ' ' '\n' | sort -u | tr '\n' ' ')
  divider && echo -e "$info [INFO] The following products failed to install successfully:\n"
  listCounter=1
  for eachFailedProducts in ${ARRAY_FOR_FAILED_INSTALL_PRODUCTS[@]}; do
    echo "$listCounter. $eachFailedProducts"
    listCounter=$((listCounter + 1))
  done
fi

#-------------------------------------------------------------------------------------------------------------------
# Print the overall status
#-------------------------------------------------------------------------------------------------------------------

$DEBUG && divider && echo -e "Status:\n" && echo $STATUS | jq .

#-------------------------------------------------------------------------------------------------------------------
# Exit only if any one of the previous step(s) (addons/products/demos) changed the phase to Failed
#-------------------------------------------------------------------------------------------------------------------

check_phase_and_exit_on_failed

#-------------------------------------------------------------------------------------------------------------------
# Change final status to Running at end of installation
#-------------------------------------------------------------------------------------------------------------------

divider && echo -e "$tick [SUCCESS] Successfully installed all selected addons, products and demos. Changing the overall status to 'Running'..."
update_phase "Running"
divider
