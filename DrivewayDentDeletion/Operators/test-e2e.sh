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
#   -n : <NAMESPACE> (string), namespace for the 1-click uninstallation. Defaults to "cp4i"
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#
# USAGE:
#   With defaults values
#     ./test-e2e.sh
#
#   Overriding the namespace and release-name
#     ./test-e2e.sh -n <NAMESPACE> -r <FORKED_REPO> -b <BRANCH>

function divider() {
    echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
    echo -e "\nUsage: $0 -n <NAMESPACE> -r <FORKED_REPO> -b <BRANCH>"
    divider
    exit 1
}

function wait_for_trigger_url() {
    time=0
    echo "INFO: Waiting for upto 5 minutes for the trigger url to be available to be available before triggering the pipeline"
    URL=$(echo "$(oc get route el-main-trigger-route --template='http://{{.spec.host}}')")
    RESULT_TRIGGER_URL=$(echo $?)
    while [ "$RESULT_TRIGGER_URL" -ne "0" ]; do
        if [ $time -gt 5 ]; then
            echo "ERROR: Timed-out waiting for the trigger url to be available to be available before triggering the pipeline"
            echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
            exit 1
        fi

        oc get route el-main-trigger-route --template='http://{{.spec.host}}'
        echo -e "\n$INFO INFO: The trigger url to be available is not yet available, waiting for upto 5 minutes. Waited ${time} minute(s)."
        time=$((time + 1))
        sleep 60
        URL=$(echo "$(oc get route el-main-trigger-route --template='http://{{.spec.host}}')")
        RESULT_TRIGGER_URL=$(echo $?)
    done
}

function print_pipelinerun_logs() {
    # $TKN pr logs $(tkn pr ls | grep Running | awk '{print $1}') -f
    $TKN pr logs --last -f
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
    echo -e "$cross ERROR: Driveway Dent deletion testing namespace is empty. Please provide a value for '-n' parameter."
    missingParams="true"
fi

if [[ -z "${FORKED_REPO// /}" ]]; then
    echo -e "$cross ERROR: Driveway Dent deletion testing repository is empty. Please provide a value for '-r' parameter."
    missingParams="true"
fi

if [[ -z "${BRANCH// /}" ]]; then
    echo -e "$cross ERROR: Driveway Dent deletion testing branch is empty. Please provide a value for '-b' parameter."
    missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
    usage
fi

divider
echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info  Driveway Dent deletion testing namespace: $NAMESPACE"
echo -e "$info  Driveway Dent deletion testing repository: $FORKED_REPO"
echo -e "$info  Driveway Dent deletion testing branch: $BRANCH"
divider

oc project $NAMESPACE

divider

echo -e "INFO: Checking if tekton-cli is pre-installed..."
tknInstalled=false
TKN=tkn
$TKN version

if [ $? -ne 0 ]; then
    tknInstalled=false
else
    tknInstalled=true
fi

if [[ "$tknInstalled" == "false" ]]; then
    echo "INFO: Installing tekton cli..."
    if [[ $(uname) == Darwin ]]; then
        echo "INFO: Installing on MAC"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        brew tap tektoncd/tools
        brew install tektoncd/tools/tektoncd-cli
    else
        echo "INFO: Installing on Linux"
        # Get the tar
        curl -LO https://github.com/tektoncd/cli/releases/download/v0.12.0/tkn_0.12.0_Linux_x86_64.tar.gz
        # Extract tkn to current directory
        tar xvzf tkn_0.12.0_Linux_x86_64.tar.gz -C . tkn
        untarStatus=$(echo $?)
        if [[ "$untarStatus" -ne 0 ]]; then
            echo -e "\n$cross ERROR: Could not extract the tar for tkn"
            exit 1
        fi

        chmod +x ./tkn
        chmodStatus=$(echo $?)
        if [[ "$chmodStatus" -ne 0 ]]; then
            echo -e "\n$cross ERROR: Could not make the 'tkn' executable"
            exit 1
        fi

        TKN=./tkn
    fi
fi

divider

./Operators/cicd-apply-dev-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH

wait_for_trigger_url
curl $URL

divider

# tkn pr logs $(tkn pr ls | grep Running | awk '{print $1}') -f
print_pipelinerun_logs

divider

# call continuous load script with defaults and get process id for it
./continuous-load.sh -n $NAMESPACE &
PID_CONTINUOUS_LOAD_DEV=$!

# wait for some continuous load output
sleep 60

./Operators/cicd-apply-test-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH

divider

wait_for_trigger_url
curl $URL

divider

# tkn pr logs $(tkn pr ls | grep Running | awk '{print $1}') -f
print_pipelinerun_logs

divider

./Operators/cicd-apply-test-apic-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH

divider

wait_for_trigger_url
curl $URL

divider

# tkn pr logs $(tkn pr ls | grep Running | awk '{print $1}') -f
print_pipelinerun_logs

# divider
# ./EventEnabledInsurance/prereqs.sh -n $NAMESPACE -b $BRANCH -r $FORKED_REPO

divider

echo -e "$INFO INFO: Stopping the continuous load script for default..."
kill -9 $PID_CONTINUOUS_LOAD_DEV
