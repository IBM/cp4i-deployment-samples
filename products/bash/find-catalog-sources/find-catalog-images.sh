#!/bin/bash

SCRIPT_DIR=$(dirname $0)

# Data copied from the table in https://www.ibm.com/docs/en/cloud-paks/cp-integration/2022.4?topic=images-adding-catalog-sources-cluster
CASES="IBM Cloud Pak for Integration	export CASE_NAME=ibm-integration-platform-navigator && export CASE_VERSION=7.0.4
IBM Automation foundation assets	export CASE_NAME=ibm-integration-asset-repository && export CASE_VERSION=1.5.8
IBM Cloud Pak for Integration Operations Dashboard	export CASE_NAME=ibm-integration-operations-dashboard && export CASE_VERSION=2.6.11
IBM API Connect	export CASE_NAME=ibm-apiconnect && export CASE_VERSION=4.0.4
IBM App Connect	export CASE_NAME=ibm-appconnect && export CASE_VERSION=8.1.0
IBM MQ	export CASE_NAME=ibm-mq && export CASE_VERSION=2.3.3
IBM Event Streams	export CASE_NAME=ibm-eventstreams && export CASE_VERSION=1.7.6
IBM DataPower Gateway	export CASE_NAME=ibm-datapower-operator && export CASE_VERSION=1.6.7
IBM Aspera HSTS	export CASE_NAME=ibm-aspera-hsts-operator && export CASE_VERSION=1.5.7
IBM Cloud Pak foundational services	export CASE_NAME=ibm-cp-common-services && export CASE_VERSION=1.19.4"

IFS='
'
export ARCH=amd64

for CASE in ${CASES}; do
    CASE_DESCRIPTION=$(echo "$CASE" | cut -f1)
    eval "$(echo "$CASE" | cut -f2)"

    echo "CASE_DESCRIPTION=$CASE_DESCRIPTION"
    echo "CASE_NAME=${CASE_NAME}"
    echo "CASE_VERSION=${CASE_VERSION}"

    oc ibm-pak get ${CASE_NAME} --version ${CASE_VERSION}
    oc ibm-pak generate mirror-manifests ${CASE_NAME} icr.io --version ${CASE_VERSION}

    echo ""
    echo ""
    echo ""
done

for CASE in ${CASES}; do
    CASE_DESCRIPTION=$(echo "$CASE" | cut -f1)
    eval "$(echo "$CASE" | cut -f2)"

    echo "#"
    echo "# ${CASE_DESCRIPTION}"
    echo "# ${CASE_NAME} ${CASE_VERSION}"
    echo "#"
    echo "---"
    if cat ~/.ibm-pak/data/mirror/${CASE_NAME}/${CASE_VERSION}/catalog-sources.yaml 2>/dev/null; then
        echo "---"
    fi
    if cat ~/.ibm-pak/data/mirror/${CASE_NAME}/${CASE_VERSION}/catalog-sources-linux-${ARCH}.yaml 2>/dev/null; then
        echo "---"
    fi
done
