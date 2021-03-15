#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
export namespace=dan
oc new-project ${namespace}

./create-catalog-sources.sh -p
./deploy-og-sub.sh -n ${namespace} -p

./release-navigator.sh -n ${namespace}

# Get cs admin username/password
oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode ; echo ""
oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode ; echo ""

# Change the CS admin password
#./change-cs-credentials.sh -u admin -p <new password>

# The following run and become ready. Can't access the UI yet, see:
# https://ibm-cloud.slack.com/archives/CD885G339/p1615216416471200
./release-ace-dashboard.sh -n ${namespace}
./release-ace-designer.sh -n ${namespace}

./release-ar.sh -n ${namespace}

./release-tracing.sh -n ${namespace}
./ar_remote_create.sh -n ${namespace} -o

./release-mq.sh -n ${namespace} -t

./release-apic.sh -n ${namespace} -t

./release-es.sh -n ${namespace}

./configure-apic-v10.sh -n ${namespace}

#### TODO HERE!!!!


#./configure-apic-v10.sh -n ${namespace}

# TODO ./release-es.sh -n ${namespace}

