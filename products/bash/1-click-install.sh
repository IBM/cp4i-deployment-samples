#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
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
#   -n : <NAMESPACE> (string), namespace for the 1-click installation. Defaults to "cp4i"
#   -r : <navReplicaCount> (string), Platform navigator replicas, Defaults to 3
#   -c : <pwdChange> (string), If common services password is to be updated. Defaults to "false"
#   -u : <csDefaultAdminUser> (string), Default common service username. Defaults to "admin"
#   -p : <csDefaultAdminPassword> (string), Common service defaul admin password
#   -d : <demoPreparation> (string), If all demos are to be setup. Defaults to "false"
#   -a : <eventEnabledInsuranceDemo> (string), If event enabled insurance demo is to be setup. Defaults to "false"
#   -f : <drivewayDentDeletionDemo> (string),  If driveway dent deletion demo is to be setup. Defaults to "false"
#   -e : <demoAPICEmailAddress> (string), The email address APIC uses to notify of portal configuration. Defaults to "your@email.address"
#   -h : <demoAPICMailServerHost> (string), Host name of the mail server. Defaults to "smtp.mailtrap.io"
#   -o : <demoAPICMailServerPort> (string), Port number of the mail server. Defaults to "2525"
#   -m : <demoAPICMailServerUsername> (string), Username for the mail server. Defaults to "<your-username>"
#   -q : <demoAPICMailServerPassword> (string), Password for the mail server.
#
# USAGE:
#   With defaults values
#     ./1-click-install.sh -p <csDefaultAdminPassword> -q <demoAPICMailServerPassword>
#
#   Overriding the namespace and release-name
#     ./1-click-install.sh -n <NAMESPACE> -r <navReplicaCount> -c <pwdChange> -u <csDefaultAdminUser> -p <csDefaultAdminPassword> -d <demoPreparation> -a <eventEnabledInsuranceDemo> -f <drivewayDentDeletionDemo> -e <demoAPICEmailAddress> -h <demoAPICMailServerHost> -o <demoAPICMailServerPort> -m <demoAPICMailServerUsername> -q <demoAPICMailServerPassword>

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

while getopts "n:r:c:u:p:d:a:f:e:h:o:m:q:" opt; do
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

if ! $CURRENT_DIR/deploy-og-sub.sh -n ${NAMESPACE}; then
  echo -e "$cross ERROR: Failed to deploy the operator group and subscriptions" 1>&2
  divider
  exit 1
else
  echo -e "$tick INFO: Deployed the operator groups and subscriptions"
fi

divider

if ! $CURRENT_DIR/release-navigator.sh -n ${NAMESPACE} -r ${navReplicaCount}; then
  echo -e "$cross ERROR: Failed to release navigator" 1>&2
  divider
  exit 1
else
  echo -e "$tick INFO: Successfully released the platform navigator"
fi

divider

# Only update common services username and password if common servies is not already installed
if [ "${pwdChange}" == "true" ]; then
  if ! $CURRENT_DIR/change-cs-credentials.sh -u ${csDefaultAdminUser} -p ${csDefaultAdminPassword} ; then
    echo -e "$cross ERROR: Failed to update the common services admin username/password" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully updated the common services admin username/password"
  fi
else
  echo -e "$info INFO: Retrieve the common service username using the command 'oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode' "
  echo -e "$info INFO: Retrieve the common service password using the command 'oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode' "
fi

divider

# ----------------------------------------------- Postgres for ddd and eei ------------------------------------------------------------

if [[ "${demoPreparation}" == "true" || "${eventEnabledInsuranceDemo}" == "true" || "${drivewayDentDeletionDemo}" == "true" ]]; then
  if ! $CURRENT_DIR/release-psql.sh; then
    echo -e "$cross ERROR: Failed to release PostgreSQL" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released PostgresSQL"
    divider
  fi
fi #postgres

# -------------------------------------------------- All other demos ----------------------------------------------------------------

if [[ "${demoPreparation}" == "true" ]]; then

  if ! $CURRENT_DIR/release-ar.sh -r ar-demo -n ${NAMESPACE}; then
    echo -e "$cross ERROR: Failed to release asset repo" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released asset repo"
  fi

  divider

  if ! $CURRENT_DIR/release-ace.sh -n ${NAMESPACE}; then
    echo -e "$cross : Failed to release ace dashboard and ace designer" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released ace dashboard and ace designer"
  fi

  divider

  if ! $CURRENT_DIR/release-mq.sh -n ${NAMESPACE} -t ; then
    echo -e "$cross : Failed to release mq" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released asset repo"
    divider
  fi
fi #demoPreparation

# ------------------------------------------- Event Enabled Insurance demo specific ---------------------------------------------------

if [[ "${eventEnabledInsuranceDemo}" == "true" || "${demoPreparation}" == "true" ]]; then
  if ! $CURRENT_DIR/release-es.sh -n ${NAMESPACE}; then
    echo "ERROR: Failed to release event streams" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully released event streams"
  fi

  divider

  # call prereqs for event enabled without branch and repo params
  # branch defaults to 'main' inside the prereqs
  # repo defaults to 'https://github.com/IBM/cp4i-deployment-samples.git' inside the prereqs
  if ! $CURRENT_DIR/../../EventEnabledInsurance/prereqs.sh -n ${NAMESPACE} -b ${demoDeploymentBranch}; then
    echo "ERROR: Failed to run event enabled insurance prereqs script" 1>&2
    divider
    exit 1
  fi
fi #eventEnabledInsuranceDemo

# ------------------------------------------- Driveway Dent Deletion demo specific ---------------------------------------------------

if [[ "${drivewayDentDeletionDemo}" == "true" || "${demoPreparation}" == "true" ]]; then

  divider

  if ! $CURRENT_DIR/../../DrivewayDentDeletion/Operators/prereqs.sh -n ${NAMESPACE}; then
    echo "ERROR: Failed to run driveway dent deletion prereqs script" 1>&2
    divider
    exit 1
  fi

  divider

  if ! $CURRENT_DIR/release-tracing.sh -n ${NAMESPACE}; then
    echo "ERROR: Failed to release tracing" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released tracing"
    divider
  fi

  if ! $CURRENT_DIR/release-ace-dashboard.sh -n ${NAMESPACE}; then
    echo "ERROR: Failed to release ace dashboard" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released ace dashboard"
    divider
  fi

  if ! $CURRENT_DIR/release-apic.sh -n ${NAMESPACE} -t ; then
    echo "ERROR: Failed to release apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully released apic"
    divider
  fi

  if ! $CURRENT_DIR/register-tracing.sh -n ${NAMESPACE} ; then
    echo "ERROR: Failed to register tracing. Tracing secret not created" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully registered tracing"
    divider
  fi

  export PORG_ADMIN_EMAIL=${demoAPICEmailAddress}
  export MAIL_SERVER_HOST=${demoAPICMailServerHost}
  export MAIL_SERVER_PORT=${demoAPICMailServerPort}
  export MAIL_SERVER_USERNAME=${demoAPICMailServerUsername}
  export MAIL_SERVER_PASSWORD=${demoAPICMailServerPassword}

  if ! $CURRENT_DIR/configure-apic-v10.sh -n ${NAMESPACE} ; then
    echo "ERROR: Failed to configure apic" 1>&2
    exit 1
  else
    echo -e "$tick INFO: Successfully onfigured apic"
    divider
  fi
fi #drivewayDentDeletionDemo

# -------------------------------------------------- All other demos ----------------------------------------------------------------

if [[ "${demoPreparation}" == "true" ]]; then
  export CP_USERNAME=${csDefaultAdminUser}
  export CP_PASSWORD=${csDefaultAdminPassword}
  export CP_CONSOLE=$(oc get routes -n ibm-common-services cp-console -o jsonpath='{.spec.host}')
  if [ -z "$CP_CONSOLE" ]; then
    echo "ERROR: Failed to get cp-console host" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully got cp-console host"
  fi

  divider

  export CP_CONSOLE_URL="https://${CP_CONSOLE}"
  if ! $CURRENT_DIR/ar_remote_create.sh -r ar-demo -n ${NAMESPACE} -o; then
    echo "ERROR: Failed to create remote for Asset repo" 1>&2
    divider
    exit 1
  else
    echo -e "$tick INFO: Successfully created remote for Asset repo"
  fi
fi #demoPreparation

divider
