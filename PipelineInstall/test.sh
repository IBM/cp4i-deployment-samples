#!/bin/bash

# TODO parameterize this
namespace="test3"

# TODO need ibm-entitlement-key set as a pre-req

# TODO need to run configure-ocp-pipeline.sh first

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"

if cat tasks.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied tasks.yaml"
else
  echo -e "\n$cross ERROR: Failed to apply tasks.yaml"
  exit 1
fi

if cat pipeline.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -n ${namespace} -f -; then
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

# echo -e "\nINFO: Adding Entitled Registry secret to pipeline Service Account..."
# if ! oc get sa --namespace ${namespace} pipeline -o json | jq -r 'del(.secrets[] | select(.name == "er-pull-secret")) | .secrets += [{"name": "er-pull-secret"}]' | oc replace -f -; then
#   echo -e "ERROR: Failed to add the secret 'er-pull-secret' to the service account 'pipeline' in the '$namespace' namespace"
#   exit 1
# else
#   echo -e "INFO: Successfully added the secret 'er-pull-secret' to the service account 'pipeline' in the '$namespace' namespace"
# fi


# Work around issue that operator doesn't have permissions on operationsdashboardservicebindings/status
cat <<EOF | oc apply -f -
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
