# Initial setup for ROKS, create performance storage classes
```
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-block-performance
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-block
parameters:
  billingType: "hourly"
  classVersion: "2"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-file-performance-gid
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-file
parameters:
  billingType: "hourly"
  classVersion: "2"
  gidAllocate: "true"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

defaultStorageClass=$(oc get sc -o json | jq -r '.items[].metadata | select(.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .name')
oc patch storageclass $defaultStorageClass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
oc patch storageclass cp4i-block-performance -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

# Vars to be used later
```
namespace=cp4i
#file_storage=ibmc-file-gold-gid
#block_storage=ibmc-block-gold
block_storage="cp4i-block-performance"
file_storage="cp4i-file-performance-gid"
im_name=ddd-dev
qm_name=mq-ddd-qm-dev
```

# Create the ibm-entitlement-key secret
NOTE replace TODO with a real value!!!
```
export IMAGE_REPO=cp.icr.io
export DOCKER_REGISTRY_USER=ekey
export DOCKER_REGISTRY_PASS="TODO"
oc create secret docker-registry ibm-entitlement-key \
    --docker-server=${IMAGE_REPO} \
    --docker-username=${DOCKER_REGISTRY_USER} \
    --docker-password=${DOCKER_REGISTRY_PASS} \
    --dry-run -o yaml | oc apply -f -
```

# Run scripts to do some setup
```
../../products/bash/create-catalog-sources.sh
oc new-project ${namespace}
../../products/bash/deploy-og-sub.sh -n ${namespace}
../../products/bash/release-navigator.sh -n ${namespace} -s ${file_storage}
../../products/bash/release-ace-dashboard.sh -n ${namespace} -s ${file_storage}
../../products/bash/release-psql.sh -n ${namespace}
```

# Do initial setup and run the dev pipeline
```
# TODO The following currently doesn't set up the ACE config
./prereqs.sh -n ${namespace}

# TODO The following builds the ace images but doesn't deploy the ACE integration servers or the queuemanager
./cicd-apply-dev-pipeline.sh -n ${namespace} -f ${file_storage} -g ${block_storage} -b use-im-for-ddd -a false

# NOTE Trigger the above pipeline to create the ACE images
```

# Create initial IM with unconfigured QM
```
cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationManifest
metadata:
  name: ${im_name}
spec:
  version: 2022.4.1
  license:
    accept: true
    license: Q4-license
    use: CloudPakForIntegrationNonProduction
  storage:
    readWriteOnce:
      class: ${block_storage}
    readWriteMany:
      class: ${file_storage}
  managedInstances:
    list:
    - kind: QueueManager
      metadata:
        name: ${qm_name}
EOF
```

# Now update the queuemanager to create the queues and setup the certs
```
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${qm_name}-queues
data:
  myqm.mqsc: |
    DEFINE QLOCAL('AccidentIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('AccidentOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('BumperIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('BumperOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('CrumpledIn') DEFPSIST(YES) BOTHRESH(5) REPLACE
    DEFINE QLOCAL('CrumpledOut') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('AccidentIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('AccidentOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${qm_name}-client
spec:
  commonName: ${namespace}.${im_name}
  subject:
    organizationalUnits:
    - my-team
  secretName: ${qm_name}-client
  issuerRef:
    name: ${namespace}-${im_name}-${namespace}-${qm_name}-ef09-ibm-inte-c46d # TODO This name from the issuer created by the IM
    kind: Issuer
    group: cert-manager.io
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationManifest
metadata:
  name: ${im_name}
spec:
  version: 2022.4.1
  license:
    accept: true
    license: Q4-license
    use: CloudPakForIntegrationNonProduction
  storage:
    readWriteOnce:
      class: ${block_storage}
    readWriteMany:
      class: ${file_storage}
  managedInstances:
    list:
    - kind: QueueManager
      metadata:
        name: ${qm_name}
      spec:
        web:
          enabled: true
        queueManager:
          mqsc:
            - configMap:
                name: ${qm_name}-qm-default
                items:
                  - myqm.mqsc
            - configMap:
                name: ${qm_name}-queues
                items:
                  - myqm.mqsc
EOF
```

# Generate the MQ cert files from the secrets
cd mq-im
./generate-test-cert.sh
cd ..


# Create the ACE config for dev
NAMESPACE=${namespace}
EACH_DEPLOY_TYPE=dev
SUFFIX=ddd

WITH_TEST_TYPE=
if [[ "$EACH_DEPLOY_TYPE" == "test" ]]; then
  WITH_TEST_TYPE="-t"
fi
DB_USER=$(echo ${NAMESPACE}_${EACH_DEPLOY_TYPE}_${SUFFIX} | sed 's/-/_/g')
DB_NAME="db_$DB_USER"
EXISTING_PASSWORD=$(oc -n $NAMESPACE get secret postgres-credential-$SUFFIX-$EACH_DEPLOY_TYPE -ojsonpath='{.data.password}' 2>/dev/null)
DB_PASS=$(echo $EXISTING_PASSWORD | base64 -d)
./create-ace-config-im.sh -n ${NAMESPACE} -g ${namespace} -u "$DB_USER" -d "$DB_NAME" -p "$DB_PASS" -s "$SUFFIX" "$WITH_TEST_TYPE"

# Create the ACE integration servers
IMAGE_TAG=$(oc get is -n $namespace ddd-ace-api -o json | jq -r .status.tags[0].tag)
./release-ace-integration-server.sh -n $namespace -a false -r ddd-dev-ace-api -i image-registry.openshift-image-registry.svc:5000/$namespace/ddd-ace-api:$IMAGE_TAG -d policyproject-ddd-dev

./release-ace-integration-server.sh -n $namespace -a false -r ddd-dev-ace-acme -i image-registry.openshift-image-registry.svc:5000/$namespace/ddd-ace-acme:$IMAGE_TAG -d policyproject-ddd-dev
./release-ace-integration-server.sh -n $namespace -a false -r ddd-dev-ace-bernie -i image-registry.openshift-image-registry.svc:5000/$namespace/ddd-ace-bernie:$IMAGE_TAG -d policyproject-ddd-dev
./release-ace-integration-server.sh -n $namespace -a false -r ddd-dev-ace-chris -i image-registry.openshift-image-registry.svc:5000/$namespace/ddd-ace-chris:$IMAGE_TAG -d policyproject-ddd-dev

# Test
../../DrivewayDentDeletion/Operators/test-api-e2e.sh -n $NAMESPACE -s ddd -d dev

---
When using:
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > createcerts/server.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > createcerts/application.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > createcerts/application.key
QM_CHANNEL=ACE_SVRCONN

got:
BIP2677E: Failed to make a client connection to queue manager &apos;mqdddqmdev&apos; using hostname &apos;mq-ddd-qm-dev-ibm-mq&apos; on port &apos;1414&apos;: MQCC=2; MQRC=2393.

https://www.ibm.com/docs/en/ibm-mq/8.0?topic=codes-2393-0959-rc2393-mqrc-ssl-initialization-error
An MQCONN or MQCONNX call was issued with SSL configuration options specified, but an error occurred during the initialization of the SSL environment.

This reason code occurs in the following environments: AIX®, HP-UX, Solaris, Windows.
---
When using:
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > createcerts/server.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > createcerts/application.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > createcerts/application.key
QM_CHANNEL=ACE_SVRCONN

got:
BIP2677E: Failed to make a client connection to queue manager &apos;mqdddqmdev&apos; using hostname &apos;mq-ddd-qm-dev-ibm-mq&apos; on port &apos;1414&apos;: MQCC=2; MQRC=2540.

https://www.ibm.com/docs/en/ibm-mq/8.0?topic=SSFKSJ_8.0.0/com.ibm.mq.tro.doc/q045400_.htm
An MQCONN call was issued from a client to connect to a queue manager but the attempt to establish communication failed because the queue manager did not recognize the channel name.
---
When using:
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > createcerts/server.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > createcerts/application.crt
oc get secret $SERVER_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > createcerts/application.key
QM_CHANNEL=MTLSQMCHL

BIP2677E: Failed to make a client connection to queue manager &apos;mqdddqmdev&apos; using hostname &apos;mq-ddd-qm-dev-ibm-mq&apos; on port &apos;1414&apos;: MQCC=2; MQRC=2393.



# Tidy up:
oc delete integrationserver ddd-dev-ace-api
oc delete integrationserver ddd-dev-ace-acme
oc delete integrationserver ddd-dev-ace-bernie
oc delete integrationserver ddd-dev-ace-chris
oc delete configuration policyproject-ddd-dev
oc delete configuration application.jks
oc delete configuration application.kdb
oc delete configuration application.sth
oc delete configuration keystore-ddd
oc delete configuration serverconf-ddd
oc delete configuration setdbparms-ddd





# Another attempt:


SET CHLAUTH('MTLSQMCHL') TYPE(SSLPEERMAP) SSLPEER('CN=cp4i.ddd-dev,OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
SET CHLAUTH('MTLSQMCHL') TYPE(SSLPEERMAP) SSLPEER('OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)


```
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: qm-dan-test
data:
  myqm.mqsc: |
    DEFINE QLOCAL('AccidentIn') DEFPSIST(YES) BOTHRESH(5)
    DEFINE QLOCAL('AccidentOut') DEFPSIST(YES) BOTHRESH(5)
    DEFINE QLOCAL('BumperIn') DEFPSIST(YES) BOTHRESH(5)
    DEFINE QLOCAL('BumperOut') DEFPSIST(YES) BOTHRESH(5)
    DEFINE QLOCAL('CrumpledIn') DEFPSIST(YES) BOTHRESH(5)
    DEFINE QLOCAL('CrumpledOut') DEFPSIST(YES) BOTHRESH(5)
    DEFINE CHANNEL(MTLSQMCHL) CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCAUTH(OPTIONAL) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) ADOPTCTX(YES) CHCKCLNT(OPTIONAL) CHCKLOCL(OPTIONAL) AUTHENMD(OS)
    SET CHLAUTH('MTLSQMCHL') TYPE(SSLPEERMAP) SSLPEER('CN=cp4i.ddd-dev,OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
    REFRESH SECURITY TYPE(CONNAUTH)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('AccidentIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('AccidentOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('BumperOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledIn') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    SET AUTHREC PROFILE('CrumpledOut') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationManifest
metadata:
  name: ${im_name}
spec:
  version: 2022.4.1
  license:
    accept: true
    license: Q4-license
    use: CloudPakForIntegrationNonProduction
  storage:
    readWriteOnce:
      class: ${block_storage}
    readWriteMany:
      class: ${file_storage}
  managedInstances:
    list:
    - kind: QueueManager
      metadata:
        name: ${qm_name}
      spec:
        web:
          enabled: true
        queueManager:
          mqsc:
            - configMap:
                name: qm-dan-test
                items:
                  - myqm.mqsc
EOF
```
