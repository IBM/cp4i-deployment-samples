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
while getopts "n" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo "INFO: Namespace= ${namespace}"
cd "$(dirname $0)"


echo "INFO: Installing tekton and its pre-reqs"
oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
echo "INFO: Installing tekton triggers"
oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
echo "INFO: Waiting for tekton and triggers deployment to finish..."
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller tekton-pipelines-webhook tekton-triggers-controller tekton-triggers-webhook

mkdir -p ${PWD}/tmp
mkdir -p ${PWD}/DefaultPolicies
echo "INFO: Creating policyproject for ace"
echo "************************************"
echo "INFO: Creating default.policyxml"
cat << EOF > ${PWD}/DefaultPolicies/default.policyxml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="MQEndpoint" policyName="MQEndpointPolicy" policyTemplate="MQEndpoint">
    <connection>CLIENT</connection>
    <destinationQueueManagerName>mqddddev</destinationQueueManagerName>
    <queueManagerHostname>mqddddev-ibm-mq</queueManagerHostname>
    <listenerPortNumber>1414</listenerPortNumber>
    <channelName>ACE_SVRCONN</channelName>
    <securityIdentity></securityIdentity>
    <useSSL>false</useSSL>
    <SSLPeerName></SSLPeerName>
    <SSLCipherSpec></SSLCipherSpec>
  </policy>
</policies>
EOF

echo "INFO: Creating policy.descriptor"
cat << EOF > ${PWD}/DefaultPolicies/policy.descriptor
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
  <references/>
</ns2:policyProjectDescriptor>
EOF

echo "INFO: Listing the files in ${PWD}/DefaultPolicies"
ls ${PWD}/DefaultPolicies

#echo "INFO: Installing the zip utility"
#yum -y install zip

zip -r DefaultPolicies/policyproject.zip DefaultPolicies/

echo "INFO: encoding the policy project"
temp=$(base64 --wrap=0 ${PWD}/DefaultPolicies/policyproject.zip)

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
