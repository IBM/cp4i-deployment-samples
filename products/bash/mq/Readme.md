# Using TLS to communicate between ACE and MQ

## Setting up MQ to use TLS

### Create Queues 
- Queues need to be configured to use:
 
 - SSL
 - Assigning user to Queues
 - Assigning permission to the User

 ```
    DEFINE QLOCAL('AccidentIn') DEFPSIST(YES) \n\
    DEFINE QLOCAL('AccidentOut') DEFPSIST(YES) \n\
    DEFINE QLOCAL('BumperIn') DEFPSIST(YES) \n\
    DEFINE QLOCAL('BumperOut') DEFPSIST(YES) \n\
    DEFINE QLOCAL('CrumpledIn') DEFPSIST(YES) \n\
    DEFINE QLOCAL('CrumpledOut') DEFPSIST(YES) \n\
    DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ECDHE_RSA_AES_128_CBC_SHA256') \n\
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) ADOPTCTX(YES) CHCKCLNT(OPTIONAL) CHCKLOCL(OPTIONAL) AUTHENMD(OS) \n\
    SET CHLAUTH('ACE_SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=application1,OU=app team1') USERSRC(MAP) MCAUSER('mqm') ACTION(ADD) \n\
    REFRESH SECURITY TYPE(CONNAUTH) \n\
    SET AUTHREC PRINCIPAL('mqm') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ) \n\
    SET AUTHREC PROFILE('AccidentIn') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
    SET AUTHREC PROFILE('AccidentOut') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
    SET AUTHREC PROFILE('BumperIn') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
    SET AUTHREC PROFILE('BumperOut') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
    SET AUTHREC PROFILE('CrumpledIn') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
    SET AUTHREC PROFILE('CrumpledOut') PRINCIPAL('mqm') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT) \n\
```

- Setup certs,keys,keystores,truststores for MQ
    
    We have used this [script](./createcerts/generate-test-cert.sh) to create the certs.
    When creating application.kdb we need to add the `aceclient` label so that ACE Integration Servers can recognize it

    I used the following command to add the label:

    `runmqckm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient`

    Note: runmqckm utility is available as a part of IBM MQ Client package and needs to be installed separately.

- Setup CR and secrets for MQ:
  
    For MQ to utilize the certs that are part of the trust and keystore we create a secret called `mqcert` with the server key, server cert and application cert.

    ```
    QM_KEY=$(cat $CURRENT_DIR/mq/createcerts/server.key | base64 -w0)
    QM_CERT=$(cat $CURRENT_DIR/mq/createcerts/server.crt | base64 -w0)
    APP_CERT=$(cat $CURRENT_DIR/mq/createcerts/application.crt | base64 -w0)

    kind: Secret
    apiVersion: v1
    metadata:
      name: mqcert
      namespace: $namespace
    data:
      tls.key: $QM_KEY
      tls.crt: $QM_CERT
      app.crt: $APP_CERT
    type: Opaque
    ```

    For MQ to use this secret and to enable auth we use a modified CR of MQ:

  ```yaml
  apiVersion: mq.ibm.com/v1beta1
  kind: QueueManager
  metadata:
    name: ${release_name}
    namespace: ${namespace}
  spec:
    license:
      accept: true
      license: L-RJON-BN7PN3
      use: NonProduction
    pki:
      keys:
        - name: default
          secret:
            items:
              - tls.key
              - tls.crt
            secretName: mqcert
      trust:
        - name: app
          secret:
            items:
              - app.crt
            secretName: mqcert
    queueManager:
      image: ${image_name}
      imagePullPolicy: Always
      name: ${qm_name}
      storage:
        queueManager:
          type: ephemeral
      ini:
        - configMap:
            items:
              - example.ini
            name: mtlsmqsc
    template:
      pod:
        containers:
          - env:
              - name: MQS_PERMIT_UNKNOWN_ID
                value: 'true'
            name: qmgr
    version: 9.2.0.0-r1
    web:
      enabled: true
    tracing:
      enabled: ${tracing_enabled}
      namespace: ${tracing_namespace}
  ```

## Setting up ACE to use TLS

For ACE to use the TLS configuration we need provide the following `ace-configuration` to ACE integration server CR:

```yaml
#serverconf.yaml:
serverConfVersion: 1
BrokerRegistry:
   mqKeyRepository: /home/aceuser/keystores/application

apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ace-serverconf
  namespace: cp4i-ddd-test
spec:
  contents: <Base 64 encoded serverconf.yaml>
  type: serverconf
```

```yaml
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: application.kdb
  namespace: cp4i-ddd-test
spec:
  contents: <base64 encoded for application.kdb>
  type: keystore
```
```yaml
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: application.sth
  namespace: cp4i-ddd-test
spec:
  contents: <base64 encoded for application.sth>
  type: keystore
 ```

```yaml
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: application.jks
  namespace: cp4i-ddd-test
spec:
  contents: <base64 encoded for application.jks>
  type: truststore
```

```yaml
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ace-setdbparms
  namespace: cp4i-ddd-test
spec:
  contents: <base64 encoded brokerTruststore::<password set in cert> dummy <password set in cert>>
  type: setdbparms
```

The ACE Integration Server CR needs to contain these configurations:

```yaml
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: ${is_release_name}
  namespace: ${namespace}
spec:
  pod:
   containers:
     runtime:
       image: ${is_image_name}
  configurations:
  - ace-serverconf
  - ace-setdbparms
  - application.kdb
  - application.sth
  - application.jks
  designerFlowsOperationMode: disabled
  license:
    accept: true
    license: 
    use: CloudPakForIntegrationProduction
  replicas: 2
  router:
    timeout: 120s
  service:
    endpointType: https
  useCommonServices: true
  version: 11.0.0.10-r1
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
```



