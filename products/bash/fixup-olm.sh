#!/bin/bash

OLM_NS="openshift-operator-lifecycle-manager"
CATALOG_OPERATOR_LABEL="app=catalog-operator"
OLM_OPERATOR_LABEL="app=olm-operator"
ONE_CLICK_NAMESPACE="cp4i"
CS_NAMESPACE="ibm-common-services"
DRY_RUN=true

echo "Checking OLM..."
CATALOG_RESTART_COUNT=$(oc get pod -n $OLM_NS -l $CATALOG_OPERATOR_LABEL -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
# Check if the catalog pod has restarted
# Delete the OLM pods if so
if [ "$CATALOG_RESTART_COUNT" -gt "0" ]; then
  if [[ "${DRY_RUN}" == "false" ]]; then
    echo "Catalog operator has restarted, restarting OLM pods..."
    oc delete pod -n ${OLM_NS} -l ${CATALOG_OPERATOR_LABEL}
    oc delete pod -n ${OLM_NS} -l ${OLM_OPERATOR_LABEL}
    oc wait --for condition=ready --timeout=120s pod -n ${OLM_NS} -l ${CATALOG_OPERATOR_LABEL}
    oc wait --for condition=ready --timeout=120s pod -n ${OLM_NS} -l ${OLM_OPERATOR_LABEL}
  else
    echo "Catalog operator has restarted, the catalog/OLM pods need to be restarted..."
  fi
fi



echo "Checking operator subscriptions..."
# Get a list of all subscriptions that have the ResolutionFailed condition
rows=$(oc get subscription --all-namespaces -o json | jq -r '.items[] | select(.status.conditions[].type == "ResolutionFailed") | {namespace:.metadata.namespace, name:.metadata.name, currentCSV:.status.currentCSV} | @base64')
for row in ${rows}; do
  _jq() {
   echo ${row} | base64 --decode | jq -r ${1}
  }

  # Check if the namespace is for 1-click or CS
  subscription_namespace="$(_jq '.namespace')"
  subscription_name="$(_jq '.name')"
  if [[ "$subscription_namespace" == "$ONE_CLICK_NAMESPACE" ]] || [[ "$subscription_namespace" == "$CS_NAMESPACE" ]]; then
    # Auto delete the csv/subscription
    current_csv=$(_jq '.currentCSV')
    if [[ ! -z "${current_csv}" ]] && [[ "${current_csv}" != "null" ]] ; then
      if [[ "${DRY_RUN}" == "false" ]]; then
        oc delete csv -n ${subscription_namespace} ${current_csv}
      else
        echo "The csv named [${current_csv}] in the [$(_jq '.namespace')] namespace needs to be deleted."
      fi
    fi
    if [[ "${DRY_RUN}" == "false" ]]; then
      oc delete subscription -n ${subscription_namespace} ${subscription_name}
      if [[ "$subscription_namespace" == "$CS_NAMESPACE" ]]; then
        sleep 5
      fi
    else
      echo "The subscription named [${subscription_name}] in the [${subscription_namespace}] namespace needs to be deleted and recreated."
    fi
  else
    echo "The operator named [${subscription_name}] in the [${subscription_namespace}] namespace needs to be deleted and re-installed."
  fi
done
