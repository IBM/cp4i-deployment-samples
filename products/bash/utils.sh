#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

export TICK="\xE2\x9C\x85"
export CROSS="\xE2\x9D\x8C"
export ALL_DONE="\xF0\x9F\x92\xAF"
export INFO="\xE2\x84\xB9"

# This will retry every 5 seconds for 10 minutes
RETRY_INTERVAL=5
RETRY_COUNT=120

function OCApplyYAML() {
  NAMESPACE=${1}
  yaml=${2}

  # For debug output uncomment the following:
  # echo "Applying the following yaml in the ${NAMESPACE} project:"
  # echo "${yaml}"

  time=0
  until cat <<EOF | oc apply -n ${NAMESPACE} -f -; do
${yaml}
EOF
    if [ $time -gt $RETRY_COUNT ]; then
      echo "ERROR: Exiting installation as timeout waiting for oc apply to work"
      exit 1
    fi
    echo "INFO: oc apply failed, will retry in $RETRY_INTERVAL seconds"
    time=$((time + 1))
    sleep $RETRY_INTERVAL
  done
}
