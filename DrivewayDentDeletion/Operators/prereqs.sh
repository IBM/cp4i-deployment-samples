#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
function usage {
    echo "Usage: $0 -n <namespace>"
}

namespace="cp4i"
while getopts "n:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

oc adm policy add-scc-to-group privileged system:serviceaccounts:$namespace
echo "INFO: Namespace= ${namespace}"
cd "$(dirname $0)"

echo "INFO: Installing tekton and its pre-reqs"
oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
echo "INFO: Installing tekton triggers"
oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
echo "INFO: Waiting for tekton and triggers deployment to finish..."
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller tekton-pipelines-webhook tekton-triggers-controller tekton-triggers-webhook

echo "Creating secrets to push images to openshift local registry"
export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot
kubectl -n ${namespace} create serviceaccount image-bot
oc -n ${namespace} policy add-role-to-user registry-editor system:serviceaccount:${namespace}:image-bot
export password="$(oc -n ${namespace} serviceaccounts get-token image-bot)"
oc create -n $namespace secret docker-registry cicd-${namespace} \
  --docker-server=$DOCKER_REGISTRY --docker-username=$username --docker-password=$password \
  --dry-run -o yaml | oc apply -f -

# Creating a new secret as the type of entitlement key is 'kubernetes.io/dockerconfigjson' but we need secret of type 'kubernetes.io/basic-auth' to pull imags from the ER
export ER_REGISTRY=$(oc get secret -n ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths' | jq 'keys[]' | tr -d '"')
export ER_USERNAME=$(oc get secret -n ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".username')
export ER_PASSWORD=$(oc get secret -n ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".password')

echo "Creating secret to pull base images from Entitled Registry"
cat << EOF | oc apply --namespace ${namespace} -f -
apiVersion: v1
kind: Secret
metadata:
  name: er-pull-secret
  annotations:
    tekton.dev/docker-0: ${ER_REGISTRY}
type: kubernetes.io/basic-auth
stringData:
  username: ${ER_USERNAME}
  password: ${ER_PASSWORD}
EOF

mkdir -p ${PWD}/tmp
# mkdir -p ${PWD}/DefaultPolicies
# echo "INFO: Creating policyproject for ace"
# echo "************************************"
# echo "INFO: Creating default.policyxml"
# cat << EOF > ${PWD}/DefaultPolicies/default.policyxml
# <?xml version="1.0" encoding="UTF-8"?>
# <policies>
#   <policy policyType="MQEndpoint" policyName="MQEndpointPolicy" policyTemplate="MQEndpoint">
#     <connection>CLIENT</connection>
#     <destinationQueueManagerName>QUICKSTART</destinationQueueManagerName>
#     <queueManagerHostname>mq-ddd-qm-ibm-mq</queueManagerHostname>
#     <listenerPortNumber>1414</listenerPortNumber>
#     <channelName>ACE_SVRCONN</channelName>
#     <securityIdentity></securityIdentity>
#     <useSSL>false</useSSL>
#     <SSLPeerName></SSLPeerName>
#     <SSLCipherSpec></SSLCipherSpec>
#   </policy>
# </policies>
# EOF

# echo "INFO: Creating policy.descriptor"
# cat << EOF > ${PWD}/DefaultPolicies/policy.descriptor
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
# <ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
#   <references/>
# </ns2:policyProjectDescriptor>
# EOF

echo "INFO: Listing the files in ${PWD}/DefaultPolicies"
ls ${PWD}/DefaultPolicies

# zip -r DefaultPolicies/policyproject.zip DefaultPolicies/

echo "INFO: encoding the policy project"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  temp=$(base64 --wrap=0 ${PWD}/DefaultPolicies/policyproject.zip)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  temp=$(base64 ${PWD}/DefaultPolicies/policyproject.zip)
else
  temp=$(base64 --wrap=0 ${PWD}/DefaultPolicies/policyproject.zip)
fi

configyaml="\
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ace-policyproject
  namespace: ${namespace}
spec:
  contents: "$temp"
  type: policyproject
"
echo "${configyaml}" > ${PWD}/tmp/policy-project-config.yaml
echo "INFO: Output -> policy-project-config.yaml"
cat ${PWD}/tmp/policy-project-config.yaml
oc apply -f ${PWD}/tmp/policy-project-config.yaml

echo "Waiting for postgres to be ready"
oc wait -n postgres --for=condition=available deploymentconfig --timeout=20m postgresql

echo "Creating quotes table in postgres samepledb"
oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
  -- psql -U admin -d sampledb -c \
'CREATE TABLE IF NOT EXISTS QUOTES (
  QuoteID SERIAL PRIMARY KEY NOT NULL,
  Name VARCHAR(100),
  EMail VARCHAR(100),
  Address VARCHAR(100),
  USState VARCHAR(100),
  LicensePlate VARCHAR(100),
  ACMECost INTEGER,
  ACMEDate DATE,
  BernieCost INTEGER,
  BernieDate DATE,
  ChrisCost INTEGER,
  ChrisDate DATE);'
