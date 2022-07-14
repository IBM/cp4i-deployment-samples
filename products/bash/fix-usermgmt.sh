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
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to "cp4i"

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
namespace="cp4i"

function usage() {
  echo "Usage: $0 -n <namespace>"
}

while getopts "n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

if ! oc logs -n ${namespace} -l component=usermgmt | grep "mkdir: cannot create directory '/user-home/_global_/config/oidc': File exists"; then
  exit 0
fi

echo "'/user-home/_global_/config/oidc' is a file when it should be a dir, fixing..."

echo "Run the fix-usermgmt-oidc job to delete the /user-home/_global_/config/oidc file"
YAML=$(cat <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  namespace: ${namespace}
  name: fix-usermgmt-oidc
spec:
  template:
    spec:
      containers:
      - name: fix-usermgmt-oidc
        image: registry.access.redhat.com/ubi8/ubi-minimal
        command:
        - rm
        - -rf
        - /user-home/_global_/config/oidc
        volumeMounts:
        - mountPath: /user-home
          name: user-home-mount
      restartPolicy: Never
      volumes:
      - name: user-home-mount
        persistentVolumeClaim:
          claimName: user-home-pvc
  backoffLimit: 4
EOF
)
OCApplyYAML "$namespace" "$YAML"

echo "Wait for usermgmt pods to come back up"
oc wait --for=condition=available deployment --timeout=10m usermgmt -n ${namespace}

echo "Delete the fix-usermgmt-oidc job"
oc delete job fix-usermgmt-oidc -n ${namespace}

echo "Populate the directory with certs and an oidcConfig.json file"
# Don't worry if this fails due to the job not existing, it will run later and populate at that point
oc get job iam-config-job -o json -n ${namespace} | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc -n ${namespace} replace --force -f -
