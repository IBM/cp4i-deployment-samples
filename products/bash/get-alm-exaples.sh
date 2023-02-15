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
# PARAMETERS:
#   -n : <namespace> (string), Defaults to "cp4i"
#

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

NAMESPACE="cp4i"

while getopts "n:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

SUBSCRIPTION_NAME="ibm-integration-platform-navigator-ibm-integration-platform-navigator-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
nav_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="PlatformNavigator")]')
echo "###################################"
echo "# Examples for release-navigator.sh"
echo "###################################"
echo $nav_examples | yq r -P -

SUBSCRIPTION_NAME="ibm-appconnect-appconnect-operator-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
ace_dashboard_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="Dashboard")]')
ace_dashboard_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="Dashboard") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
ace_designer_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="DesignerAuthoring")]')
ace_designer_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="DesignerAuthoring") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
ace_integration_server_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="IntegrationServer")]')
ace_integration_server_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="IntegrationServer") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
echo ""
echo "#######################################"
echo "# Examples for release-ace-dashboard.sh"
echo "#######################################"
echo $ace_dashboard_examples | yq r -P -
echo "#######################################"
echo "# Versions for release-ace-dashboard.sh"
echo "#######################################"
echo $ace_dashboard_versions | yq r -P -
echo ""
echo "######################################"
echo "# Examples for release-ace-designer.sh"
echo "######################################"
echo $ace_designer_examples | yq r -P -
echo "######################################"
echo "# Versions for release-ace-designer.sh"
echo "######################################"
echo $ace_designer_versions | yq r -P -
echo ""
echo "################################################"
echo "# Examples for release-ace-integration-server.sh"
echo "################################################"
echo $ace_integration_server_examples | yq r -P -
echo "################################################"
echo "# Versions for release-ace-integration-server.sh"
echo "################################################"
echo $ace_integration_server_versions | yq r -P -

SUBSCRIPTION_NAME="ibm-apiconnect-ibm-apiconnect-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
apic_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="APIConnectCluster")]')
apic_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="APIConnectCluster") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
echo ""
echo "##############################"
echo "# Examples for release-apic.sh"
echo "##############################"
echo $apic_examples | yq r -P -
echo "##############################"
echo "# Versions for release-apic.sh"
echo "##############################"
echo $apic_versions | yq r -P -

SUBSCRIPTION_NAME="ibm-integration-asset-repository-ibm-integration-asset-repository-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
ar_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="AssetRepository")]')
ar_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="AssetRepository") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
echo ""
echo "############################"
echo "# Examples for release-ar.sh"
echo "############################"
echo $ar_examples | yq r -P -
echo "############################"
echo "# Versions for release-ar.sh"
echo "############################"
echo $ar_versions | yq r -P -

SUBSCRIPTION_NAME="ibm-eventstreams-ibm-eventstreams-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
es_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="EventStreams")]')
es_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="EventStreams") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
echo ""
echo "############################"
echo "# Examples for release-es.sh"
echo "############################"
echo $es_examples | yq r -P -
echo "############################"
echo "# Versions for release-es.sh"
echo "############################"
echo $es_versions | yq r -P -

SUBSCRIPTION_NAME="ibm-mq-ibm-mq-operator-catalog-openshift-marketplace"
csv=$(oc get subscription -n ${NAMESPACE} ${SUBSCRIPTION_NAME} -o json | jq -r .status.currentCSV)
mq_examples=$(oc get csv $csv -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.alm-examples}' | jq '[.[] | select(.kind=="QueueManager")]')
# mq_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="QueueManager") | .specDescriptors[] | select(.path=="version") | ."x-descriptors"')
mq_versions=$(oc get csv $csv -n ${NAMESPACE} -o json | jq '.spec.customresourcedefinitions.owned[] | select(.kind=="QueueManager") | .specDescriptors[] | select(.path=="version") | .description')
echo ""
echo "############################"
echo "# Examples for release-mq.sh"
echo "############################"
echo $mq_examples | yq r -P -
echo "############################"
echo "# Versions for release-mq.sh"
echo "############################"
echo $mq_versions
