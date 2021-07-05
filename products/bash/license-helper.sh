#!/bin/bash
#*******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#*******************************************************************************

#*******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.6/cli_reference/openshift_cli/getting-started-cli.html)
#
# USAGE:
#   source ./license-helper.sh; getAceLicense $NAMESPACE
#*******************************************************************************

LICENSES_CM="demo-licenses"
DEFAULT_ACE="L-KSBM-C37J2R"
DEFAULT_APIC="L-RJON-BZEP9N"
DEFAULT_AR="L-NCAN-C3CJ8D"
DEFAULT_DEMO="L-RJON-BYRMYW"
DEFAULT_MQ="L-RJON-BXUPZ2"
DEFAULT_TRACING="CP4I"

function usage() {
  echo "Usage: source $0; getAceLicense \$NAMESPACE"
}

while getopts "" opt; do
  case ${opt} in
  \?)
    usage
    exit
    ;;
  esac
done

function getACELicense() {
  ACE_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.ace}' 2>/dev/null)
  [[ $? == 0 && !$ACE_LICENSE == '' ]] && echo $ACE_LICENSE || echo $DEFAULT_ACE
}

function getAPICLicense() {
  APIC_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.apic}' 2>/dev/null)
  [[ $? == 0 && !$APIC_LICENSE == '' ]] && echo $APIC_LICENSE || echo $DEFAULT_APIC
}

function getARLicense() {
  AR_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.ar}' 2>/dev/null)
  [[ $? == 0 && !$AR_LICENSE == '' ]] && echo $AR_LICENSE || echo $DEFAULT_AR
}

function getDemoLicense() {
  DEMO_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.demo}' 2>/dev/null)
  [[ $? == 0 && !$DEMO_LICENSE == '' ]] && echo $DEMO_LICENSE || echo $DEFAULT_DEMO
}

function getMQLicense() {
  MQ_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.mq}' 2>/dev/null)
  [[ $? == 0 && !$MQ_LICENSE == '' ]] && echo $MQ_LICENSE || echo $DEFAULT_MQ
}

function getTracingLicense() {
  TRACING_LICENSE=$(oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.tracing}' 2>/dev/null)
  [[ $? == 0 && !$TRACING_LICENSE == '' ]] && echo $TRACING_LICENSE || echo $DEFAULT_TRACING
}
