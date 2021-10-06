#!/bin/bash

namespace="cp4i"
SCRIPT_DIR=$(dirname $0)

function usage() {
  echo "Usage: $0 -n <namespace>"
}

while getopts "n:r:s:p" opt; do
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

# TODO need ibm-entitlement-key set as a pre-req

# TODO Error handling
${SCRIPT_DIR}/../products/bash/install-ocp-pipeline.sh
${SCRIPT_DIR}/../products/bash/configure-ocp-pipeline.sh -n ${namespace}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"

if cat ${SCRIPT_DIR}/tasks.yaml | oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied tasks.yaml"
else
  echo -e "\n$cross ERROR: Failed to apply tasks.yaml"
  exit 1
fi

if cat ${SCRIPT_DIR}/pipeline.yaml | oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied pipeline.yaml"
else
  echo -e "\n$cross ERROR: Failed to apply pipeline.yaml"
  exit 1
fi

PIPELINE_RUN_NAME=cp4i-install
oc delete pipelinerun ${PIPELINE_RUN_NAME}


echo -e "INFO: Waiting for upto 5 minutes for 'pipeline' service account to be available...\n"
GET_PIPELINE_SERVICE_ACCOUNT=$(oc get sa  pipeline)
RESULT_GET_PIPELINE_SERVICE_ACCOUNT=$(echo $?)
time=0
while [ "$RESULT_GET_PIPELINE_SERVICE_ACCOUNT" -ne "0" ]; do
  if [ $time -gt 5 ]; then
    echo "ERROR: Timed-out waiting for 'pipeline' service account to be available"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  oc get sa pipeline
  echo -e "\nINFO: The 'pipeline' service account is not yet available, waiting for up to 5 minutes. Waited ${time} minute(s).\n"
  time=$((time + 1))
  sleep 60
  GET_PIPELINE_SERVICE_ACCOUNT=$(oc get sa pipeline)
  RESULT_GET_PIPELINE_SERVICE_ACCOUNT=$(echo $?)
done

echo -e "\nINFO: 'pipeline' service account is now available\n"
oc get sa pipeline

# TODO Need to make sure this project exists so can create Role/RoleBinding in it
oc new-project ibm-common-services

# Give the pipeline sa permissions on catalogsources/processedtemplates/operatorgroups/secrets/routes
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ibm-common-services
  name: pipelines-read-routes
rules:
- apiGroups:
  - "route.openshift.io"
  resources:
  - routes
  verbs:
  - get
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ibm-common-services
  name: pipelines-read-routes-${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-read-routes
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ibm-common-services
  name: pipelines-read-secrets-${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-read-secrets
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: openshift-marketplace
  name: pipelines-create-catalog-sources
rules:
- apiGroups:
  - operators.coreos.com
  resources:
  - catalogsources
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: openshift-marketplace
  name: pipelines-create-catalog-sources-${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-create-catalog-sources
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: openshift
  name: pipelines-create-processedtemplates
rules:
- apiGroups:
  - template.openshift.io
  resources:
  - processedtemplates
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: openshift
  name: pipelines-create-processedtemplates-${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-create-processedtemplates
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace}
  name: pipelines-create-operatorgroups
rules:
- apiGroups:
  - operators.coreos.com
  resources:
  - operatorgroups
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace}
  name: pipelines-create-operatorgroups
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-create-operatorgroups
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace}
  name: pipelines-create-roles-and-bindings
rules:
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - roles
  - rolebindings
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace}
  name: pipelines-create-roles-and-bindings
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-create-roles-and-bindings
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace}
  name: pipelines-create-od-bindings
rules:
- apiGroups:
  - integration.ibm.com
  resources:
  - operationsdashboardservicebindings/status
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace}
  name: pipelines-create-od-bindings
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipelines-create-od-bindings
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ${namespace}
EOF

cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: "${PIPELINE_RUN_NAME}"
  labels:
    app: cp4i-install
spec:
  pipelineRef:
    name: cp4i-install
EOF

pipelinerunSuccess="false"

if ! tkn pipelinerun logs -f $PIPELINE_RUN_NAME; then
  echo -e "\n$cross ERROR: Failed to get the pipelinerun logs successfully"
fi

echo -e "INFO: The pipeline run in the :\n"
oc get pipelinerun $PIPELINE_RUN_NAME

echo -e "\nINFO: The task runs :\n"
oc get taskrun

if [[ "$(oc get pipelinerun $PIPELINE_RUN_NAME -o json | jq -r '.status.conditions[0].status')" == "True" ]]; then
  pipelinerunSuccess="true"
fi

if [[ "$pipelinerunSuccess" == "false" ]]; then
  echo -e "\n$cross ERROR: The pipelinerun did not succeed\n"
  exit 1
else
  echo -e "\n$tick INFO: The pipeline run passed!\n"
fi
