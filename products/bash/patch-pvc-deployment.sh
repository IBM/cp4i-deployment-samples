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
#   -n : <NAMESPACE> (string), Namespace to run the cron job in. It is created if does not already exists. Defaults to "cp4i"
#
# USAGE:
#   With defaults values
#     ./patch-pvc-deployment.sh
#
#   Overriding the namespace
#     ./patch-pvc-deployment.sh -n <NAMESPACE>

function usage() {
  echo "Usage: $0 -n <NAMESPACE>"
}

NAMESPACE="cp4i"
SERVICE_ACCOUNT_NAME="patch-pvc-file-gid-deployment-sa"
ROLE_NAME="patch-pvc-file-gid-role"
ROLE_BINDING_NAME="patch-pvc-file-gid-role-rolebinding"
CRON_JOB_NAME="patch-file-gid-pvc-cron-job"
# run every 5 minutes
CRON_JOB_REPEAT_FREQUENCY='*/30 * * * *'

while getopts "n:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

if oc get namespace $NAMESPACE >/dev/null 2>&1; then
  echo "[INFO] The namespace $NAMESPACE already exists"
else
  echo "[INFO] Creating the '$NAMESPACE' namespace\n"
  if ! oc create namespace $NAMESPACE; then
    echo "[ERROR] Failed to create the '$NAMESPACE' namespace"
    divider
    exit 1
  else
    echo -e "\n[SUCCESS] Successfully created the '$NAMESPACE' namespace\n"
  fi
fi

cat <<EOF | oc apply -f -
apiVersion: v1	
kind: ServiceAccount	
metadata:	
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE

---

# Role to get and patch the file-gid deployment in the app api group in the kube-system namespace
kind: Role	
apiVersion: rbac.authorization.k8s.io/v1	
metadata:	
  name: $ROLE_NAME
  namespace: kube-system	
rules:	
  # Permissions to get and patch the file-gid deployment in the app api group in the kube-system namespace
  - apiGroups: ["apps"]	
    resources: ["deployments"]	
    verbs: ["get", "patch"]

---

# Role binding to get and patch the file-gid deployment
apiVersion: rbac.authorization.k8s.io/v1	
kind: RoleBinding	
metadata:	
  name: $ROLE_BINDING_NAME
  namespace: kube-system	
subjects:	
  - kind: ServiceAccount	
    name: $SERVICE_ACCOUNT_NAME
    namespace: $NAMESPACE
roleRef:	
  apiGroup: rbac.authorization.k8s.io	
  kind: Role	
  name: $ROLE_NAME

---

kind: CronJob
apiVersion: batch/v1beta1
metadata:
  name: $CRON_JOB_NAME
  namespace: $NAMESPACE
spec:
  schedule: "$CRON_JOB_REPEAT_FREQUENCY"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: oc
              image: 'quay.io/openshift/origin-cli:latest'
              args:
                - oc
                - patch
                - deployment
                - '-n'
                - kube-system
                - ibm-file-plugin
                - '-p'
                - >-
                  {"spec":{"template":{"spec":{"containers":[{"name":"ibm-file-plugin-container","securityContext":{"privileged":true,"allowPrivilegeEscalation":
                  true,"runAsNonRoot": false,"runAsUser": 0},
                  "image":"registry.ng.bluemix.net/armada-master/storage-file-plugin:384"}]}}}}
          restartPolicy: OnFailure
          serviceAccountName: $SERVICE_ACCOUNT_NAME
EOF
