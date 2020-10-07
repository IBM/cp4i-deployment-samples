#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <namespace> -r <REPO> -b <BRANCH>

function divider {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage {
    echo "Usage: $0 -n <NAMESPACE> -r <navReplicaCount> -c <pwdChange> -u <csDefaultAdminUser> -p <csDefaultAdminPassword> -d <demoPreparation> -a <eventEnabledInsuranceDemo> -f <drivewayDentDeletionDemo> -e <demoAPICEmailAddress> -h <demoAPICMailServerHost> -o <demoAPICMailServerPort> -m <demoAPICMailServerUsername> -q <demoAPICMailServerPassword>"
    divider
    exit 1
}

NAMESPACE="cp4i"
navReplicaCount="3"
pwdChange="false"
csDefaultAdminUser="admin"
demoPreparation="false"
eventEnabledInsuranceDemo="false"
drivewayDentDeletionDemo="false"
demoAPICEmailAddress="your@email.address"
demoAPICMailServerHost="smtp.mailtrap.io"
demoAPICMailServerPort="2525"
demoAPICMailServerUsername="<your-username>"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
CURRENT_DIR=$(dirname $0)
missingParams="false"

while getopts "n:r:c:u:p:d:a:f:e:h:o:m:q" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    r ) navReplicaCount="$OPTARG"
      ;;
    c ) pwdChange="$OPTARG"
      ;;
    u ) csDefaultAdminUser="$OPTARG"
      ;;
    p ) csDefaultAdminPassword="$OPTARG"
      ;;
    d ) demoPreparation="$OPTARG"
      ;;
    a ) eventEnabledInsuranceDemo="$OPTARG"
      ;;
    f ) drivewayDentDeletionDemo="$OPTARG"
      ;;
    e ) demoAPICEmailAddress="$OPTARG"
      ;;
    h ) demoAPICMailServerHost="$OPTARG"
      ;;
    o ) demoAPICMailServerPort="$OPTARG"
      ;;
    m ) demoAPICMailServerUsername="$OPTARG"
      ;;
    q ) demoAPICMailServerPassword="$OPTARG"
      ;;
    \? ) usage;
      ;;
  esac
done

if [[ -z "${NAMESPACE// }" ]]; then
  echo -e "$cross ERROR: 1-click installation namespace is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ -z "${navReplicaCount// }" ]]; then
  echo -e "$cross ERROR: Platform navigator replica count is empty. Please provide a value for '-r' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminUser// }" ]]; then
  echo -e "$cross ERROR: Default admin username is empty. Please provide a value for '-u' parameter."
  missingParams="true"
fi

if [[ -z "${demoPreparation// }" ]]; then
  echo -e "$cross ERROR: Demo preparation parameter is empty. Please provide a value for '-d' parameter."
  missingParams="true"
fi

if [[ -z "${pwdChange// }" ]]; then
  echo -e "$cross ERROR: Common service password change parameter is empty. Please provide a value for '-c' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminPassword// }" ]]; then
  echo -e "$cross ERROR: Default admin password is empty. Please provide a value for '-p' parameter."
  missingParams="true"
fi

if [[ -z "${eventEnabledInsuranceDemo// }" ]]; then
  echo -e "$cross ERROR: Event enabled insurance parameter is empty. Please provide a value for '-a' parameter."
  missingParams="true"
fi

if [[ -z "${drivewayDentDeletionDemo// }" ]]; then
  echo -e "$cross ERROR: Driveway dent deletion parameter is empty. Please provide a value for '-f' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info 1-click namespace: $NAMESPACE"
echo -e "$info Navigator replica count: $navReplicaCount"
echo -e "$info Change common service password: $pwdChange"
echo -e "$info Default common service username: $csDefaultAdminUser"
echo -e "$info Setup all demos: $demoPreparation"
echo -e "$info Setup only event enabled insurance demo: $eventEnabledInsuranceDemo"
echo -e "$info Setup only driveway dent deletion demo: $drivewayDentDeletionDemo"
echo -e "$info APIC email address: $demoAPICEmailAddress"
echo -e "$info APIC mail server hostname: $demoAPICMailServerHost"
echo -e "$info APIC mail server port: $demoAPICMailServerPort"
echo -e "$info APIC mail server username: $demoAPICMailServerUsername"
divider

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: is-designer
  namespace: cp4i1
spec:
  adminServerSecure: true
  barURL: >-
    https://ace-dashboard-demo-dash:3443/v1/directories/DrivewayDemo?95f5b0cc-6c18-4063-8063-f819f4666616
  designerFlowsOperationMode: local
  license:
    accept: true
    license: L-APEH-BPUCJK
    use: CloudPakForIntegrationProduction
  replicas: 2
  router:
    timeout: 120s
  service:
    endpointType: http
  useCommonServices: true
  version: 11.0.0.10-r1
  configurations:
    - ace-policyproject-eei
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF
