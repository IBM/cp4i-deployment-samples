#!/bin/bash

# This is to work around a known issue in OCP:
# https://www.ibm.com/support/knowledgecenter/SSHKN6/installer/3.x.x/troubleshoot/op_hang.html

# Get a list of subscriptions stuck in "UpgradePending"
SUBSCRIPTIONS=$(
  oc get subscriptions -n ibm-common-services -o json |
    jq -r '.items[] | select(.status.state=="UpgradePending") | .metadata.name'
)

if [[ "$SUBSCRIPTIONS" == "" ]]; then
  echo "No subscriptions in UpgradePending"
else
  echo "The following subscriptions are stuck in UpgradePending:"
  echo "$SUBSCRIPTIONS"

  # Get a unique list of install plans for subscriptions that are stuck in "UpgradePending"
  INSTALL_PLANS=$(
    oc get subscription -n ibm-common-services -o json |
      jq -r '[ .items[] | select(.status.state=="UpgradePending") | .status.installplan.name] | unique | .[]'
  )
  echo "Associated installplans:"
  echo "$INSTALL_PLANS"

  # Delete the InstallPlans
  oc delete installplans -n ibm-common-services $INSTALL_PLANS

  # Delete the Subscriptions
  oc delete subscriptions -n ibm-common-services $SUBSCRIPTIONS
fi
