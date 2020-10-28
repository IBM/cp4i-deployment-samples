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
#   -n : <NAMESPACE> (string), namespace for the e2e test for DDD. Defaults to "cp4i"
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#
# USAGE:
#   With defaults values
#     ./test-e2e.sh
#
#   Overriding the default paramters
#     ./test-e2e.sh -n <NAMESPACE> -r <FORKED_REPO> -b <BRANCH>
#

function divider() {
    echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
    echo -e "\nUsage: $0 -n <NAMESPACE> -r <FORKED_REPO> -b <BRANCH>"
    divider
    exit 1
}

function add_date_for_log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date)" "$line"
    done
}

function wait_and_trigger_pipeline() {
    PIPELINE_TYPE=${1}
    URL=$(oc get route -n $NAMESPACE el-main-trigger-route --template='http://{{.spec.host}}')

    # Wait for upto 5 minutes for the event listener pod to be running
    time=0
    while [ "$(oc get pod -n $NAMESPACE | grep el-$PIPELINE_TYPE-event-listener | grep 1/1 | grep Running)" == "" ]; do
        if [ $time -gt 5 ]; then
            echo -e "$CROSS ERROR: The event listner pod could not be found or did not get to Running state within 5 minutes, below is the current list of pods in the '$NAMESPACE' namespace:\n'"
            oc get pods -n $NAMESPACE
            exit 1
        fi
        echo -e "$INFO INFO: Wait for upto 5 minutes for the event listener pod to be running. Waited ${time} minute(s)."
        time=$((time + 1))
        sleep 60
    done

    echo -e "\n$INFO INFO: The event listener pod:\n"
    oc get pod -n $NAMESPACE | grep el-$PIPELINE_TYPE-event-listener | grep 1/1 | grep Running
    echo -e "\n$INFO INFO: The event listener pod is now in Running, going ahead to trigger the '$PIPELINE_TYPE' pipeline...\n"
    curl $URL
    divider
    echo -e "$INFO INFO: Printing the logs for the '$PIPELINE_TYPE' pipeline...\n"
    if ! $TKN pr logs --last -f; then
        echo -e "\n$CROSS ERROR: Could not display the logs for the '$PIPELINE_TYPE' pipeline"
        divider
        exit 1
    fi
    divider
}

function run_continous_load_script_for_100_calls() {
    divider
    ns=$1 #namespace
    apic=$2 # apic enabled
    # call continuous load script with defaults and get process id for it and log output to a file
    if [ ! -z $apic ]; then
        echo "[INFO] Running the continuous-load.sh with -a for apic"
        if ! $CURRENT_DIR/continuous-load.sh -n $ns -a | add_date_for_log >continuous-load-script-log.txt 2>&1
        then
            echo -e "$CROSS ERROR: Could not start or finish the continuous load testing, check the log file 'continuous-load-script-log.txt'."
            exit 1
        fi
    else
        if ! $CURRENT_DIR/continuous-load.sh -n $ns | add_date_for_log >continuous-load-script-log.txt 2>&1
        then
            echo -e "$CROSS ERROR: Could not start or finish the continuous load testing, check the log file 'continuous-load-script-log.txt'."
            exit 1
        fi
    fi
}


NAMESPACE="cp4i"
CURRENT_DIR=$(dirname $0)
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
INFO="\xE2\x84\xB9"
MISSING_PARAMS="false"
BRANCH="main"
FORKED_REPO="https://github.com/IBM/cp4i-deployment-samples.git"
TKN_INSTALLED=false

while getopts "n:r:b:" opt; do
    case ${opt} in
    n)
        NAMESPACE="$OPTARG"
        ;;
    r)
        FORKED_REPO="$OPTARG"
        ;;
    b)
        BRANCH="$OPTARG"
        ;;
    \?)
        usage
        ;;
    esac
done

if [[ -z "${NAMESPACE// /}" ]]; then
    echo -e "$CROSS ERROR: Driveway Dent deletion testing namespace is empty. Please provide a value for '-n' parameter."
    missingParams="true"
fi

if [[ -z "${FORKED_REPO// /}" ]]; then
    echo -e "$CROSS ERROR: Driveway Dent deletion testing repository is empty. Please provide a value for '-r' parameter."
    missingParams="true"
fi

if [[ -z "${BRANCH// /}" ]]; then
    echo -e "$CROSS ERROR: Driveway Dent deletion testing branch is empty. Please provide a value for '-b' parameter."
    missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
    usage
fi

divider
echo -e "$INFO Current directory: $CURRENT_DIR"
echo -e "$INFO Driveway Dent deletion testing namespace: $NAMESPACE"
echo -e "$INFO Driveway Dent deletion testing repository: $FORKED_REPO"
echo -e "$INFO Driveway Dent deletion testing branch: $BRANCH"
divider

oc project $NAMESPACE

divider

echo -e "$INFO INFO: Checking if tekton-cli is pre-installed...\n"
TKN=tkn
$TKN version

if [ $? -eq 0 ]; then
    TKN_INSTALLED=true
fi

if [[ "$TKN_INSTALLED" == "false" ]]; then
    echo -e "$INFO INFO: Installing tekton cli..."
    if [[ $(uname) == Darwin ]]; then
        echo -e "$INFO INFO: Installing on MAC"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        brew tap tektoncd/tools
        brew install tektoncd/tools/tektoncd-cli
    else
        echo -e "$INFO INFO: Installing on Linux"
        # Get the tar
        curl -LO https://github.com/tektoncd/cli/releases/download/v0.12.0/tkn_0.12.0_Linux_x86_64.tar.gz
        # Extract tkn to current directory
        tar xvzf tkn_0.12.0_Linux_x86_64.tar.gz -C . tkn
        UNTAR_STATUS=$(echo $?)
        if [[ "$UNTAR_STATUS" -ne 0 ]]; then
            echo -e "\n$CROSS ERROR: Could not extract the tar for 'tkn'"
            exit 1
        fi

        chmod +x ./tkn
        CHMOD_STATUS=$(echo $?)
        if [[ "$CHMOD_STATUS" -ne 0 ]]; then
            echo -e "\n$CROSS ERROR: Could not make the 'tkn' executable"
            exit 1
        fi

        TKN=./tkn
    fi
fi

divider

echo -e "$INFO INFO: Applying the dev pipeline resources...\n"
if ! $CURRENT_DIR/cicd-apply-dev-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH; then
    echo -e "$CROSS ERROR: Could not apply the dev pipeline and related resources."
    exit 1
fi

wait_and_trigger_pipeline "dev"

# running continous load script in dev namespace
run_continous_load_script_for_100_calls "$NAMESPACE"

divider

echo -e "$INFO INFO: Applying the test pipeline resources...\n"
if ! $CURRENT_DIR/cicd-apply-test-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH; then
    echo -e "$CROSS ERROR: Could not apply the test pipeline and related resources."
    exit 1
fi


divider

wait_and_trigger_pipeline "test"

run_continous_load_script_for_100_calls "$NAMESPACE"
sleep 60
run_continous_load_script_for_100_calls "$NAMESPACE-ddd-test"

divider

echo -e "$INFO INFO: Applying the test pipeline resources...\n"
if ! $CURRENT_DIR/cicd-apply-test-apic-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH; then
    echo -e "$CROSS ERROR: Could not apply the test pipeline and related resources."
    exit 1
fi

wait_and_trigger_pipeline "test-apic"

divider

run_continous_load_script_for_100_calls "$NAMESPACE" "apic"
sleep 60
run_continous_load_script_for_100_calls "$NAMESPACE-ddd-test" "apic"

divider

echo -e "$TICK $ALL_DONE INFO: The DDD E2E test ran successfully $ALL_DONE $TICK"

divider
