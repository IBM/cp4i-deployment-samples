# Name

IBM&reg; Cloud Pak for Integration

# Introduction

Configure apic for Car Crash Demo

## Usage

- `configure-apic.sh` uses and apic-configurator image to setup car crash demo in apic

- `configure-apic.sh` is called from installation script from ibm-cp-integration case.tgz (https://github.com/IBM/cloud-pak/blob/master/repo/case/ibm-cp-integration-1.0.24.tgz). Before calling the `configure-apic.sh` the install script in case.tgz does the following:

    - set pre-reqs to install APIC i.e namespace, secrets and entitlement keys

    - Install APIC using ibm-entitled charts repo

    - Set up additional Env Vars:
    ```
    creates configurator-pull-secret using entitlement key credentials
    export PORG_ADMIN_EMAIL= value provided by the user in demoAPICEmailAddress in 1-click install parameters
    export MAIL_SERVER_HOST= value provided by the user in demoAPICMailServerHost in 1-click install parameters or uses `smtp.mailtrap.io` as default
    export MAIL_SERVER_PORT= value provided by the user in demoAPICMailServerPort in 1-click install parameters or uses `2525` as default
    export MAIL_SERVER_USERNAME= value provided by the user in demoAPICMailServerUsername in 1-click install parameters
    export MAIL_SERVER_PASSWORD= value provided by the user in demoAPICMailServerPassword in 1-click install parameters
    export CONFIGURATOR_IMAGE=cp.icr.io/cp/icp4i/apic/apic-configurator:dte-21
    ```

# Setting up car crash demo outside 1-click install

User can setup car crash demo if they have got their own APIC instance outside 1-click install using the following instructions:

## Steps
- Install APIC
- Install kubectl and jq
- Set up env vars:
```
    export NAMESPACE= <your apic instance namespace>
    export IMAGE_REPO="cp.icr.io" this is your entitled registry
    export DOCKER_REGISTRY_USER= <your entitled registry user>
    export DOCKER_REGISTRY_PASS= <your entitled registry key>
    oc -n ${NAMESPACE} create secret docker-registry configurator-pull-secret \
    --docker-server=${IMAGE_REPO} \
    --docker-username=${DOCKER_REGISTRY_USER} \
    --docker-password=${DOCKER_REGISTRY_PASS} \
    --dry-run -o yaml | oc apply -f -
    export PORG_ADMIN_EMAIL=<your email-id>
    export MAIL_SERVER_HOST=<your mail server>
    export MAIL_SERVER_PORT=<your mail server port>
    export MAIL_SERVER_USERNAME=<your mail server username>
    export MAIL_SERVER_PASSWORD=<your mail server password>
    export CONFIGURATOR_IMAGE="${IMAGE_REPO}/cp/icp4i/icip-configurator:apic-dte-21"
```
- run `configure-apic.sh`

