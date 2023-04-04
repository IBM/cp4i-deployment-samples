# Overview
This dir is for a demo named "Event Enabled Insurance".

# Prerequisites
A [script](prereqs.sh) is provided to setup the prerequisites for this demo
and this script is automatically run as part of the 1-click demo preparation.
The script carries out the following:
- Installs Openshift pipelines from the ocp-4.5 channel.
- Creates a secret to allow the pipeline to pull from the entitled registry.
- Creates secrets to allow the pipeline to push images to the default project (`cp4i`).
- Creates a username and password for the dev (this is the namespace where the 1-click install ran in).
- Create a username for the postgres for this demo.
- Creates a database for the postgres for this demo.
- Creates a `QUOTES` table in the database.
- Creates an ACE configuration and dynamic policy xml for postgres in the default namespace `cp4i`.
- Does some setup to support a Debezium connector:
  - Creates a PUBLICATION named `DB_EEI_QUOTES` for the `QUOTES` table. (The Debezium connector can do this, but would then require super user privileges)
  - Creates a replication user that has the replication role and access to the `QUOTES` table
  - Creates a secret with the replication username/password that can be used by the `KafkaConnector`

# Set up a Kafka Connect environment
Download the [example kafka-connect.yaml](kafkaconnect/kafka-connect.yaml). This is based on the one in
the Event Streams toolbox, which can be accessed by:
- Navigate to the toolbox for the `es-demo` Event Streams runtime
- Click `Set up a Kafka Connect environment`

The example includes comments describing each change, see the following:
```yaml
apiVersion: eventstreams.ibm.com/v1beta2
kind: KafkaConnect
metadata:
  name: eei-cluster
  annotations:
    eventstreams.ibm.com/use-connector-resources: "true"
spec:
  replicas: 1

  # The `es-demo` Event Streams runtime is setup with no external access. This is the
  # service name of the demo bootstrap server and can only be used within the cluster.
  bootstrapServers: es-demo-kafka-bootstrap:9092

  # Set the following to the newly built custom image once it has been built and pushed to the cluster
  # image: image-registry.openshift-image-registry.svc:5000/<namespace>/eei-connect-cluster-image:latest

  template:
    pod:
      imagePullSecrets: []
      metadata:
        annotations:
          eventstreams.production.type: CloudPakForIntegrationNonProduction
          productID: 2a79e49111f44ec3acd89608e56138f5
          productName: IBM Event Streams for Non Production

          # Use the latest version of Eventstreams
          productVersion: 11.1.1

          productMetric: VIRTUAL_PROCESSOR_CORE
          productChargedContainers: eei-cluster-connect
          cloudpakId: c8b82d189e7545f0892db9ef2731b90d
          cloudpakName: IBM Cloud Pak for Integration

          # Use the latest version of Eventstreams
          cloudpakVersion: 2022.4.1

          productCloudpakRatio: "2:1"
  config:
    group.id: connect-cluster
    offset.storage.topic: connect-cluster-offsets
    config.storage.topic: connect-cluster-configs
    status.storage.topic: connect-cluster-status

    # There is no need to change the replication factors, `es-demos` has 3 replicas and so
    # the default value of 3 is appropriate.
    config.storage.replication.factor: 3
    offset.storage.replication.factor: 3
    status.storage.replication.factor: 3

    # The following 2 properties enable a class that allows reading properties from files.
    config.providers: file
    config.providers.file.class: org.apache.kafka.common.config.provider.FileConfigProvider

  # This mounts secrets into the connector at /opt/kafka/external-configuration. These
  # secrets have been pre-created by the prereqs.sh script and configure access to the
  # demo install of Postgres.
  externalConfiguration:
    volumes:
      - name: postgres-connector-config
        secret:
          secretName: eei-postgres-replication-credential

# There is no need to add tls or authentication properties, `es-demos` has no security setup.
#  tls:
#    trustedCertificates:
#      - secretName: quickstart-cluster-ca-cert
#        certificate: ca.crt
#  authentication:
#    type: scram-sha-512
#    username: my-connect-user
#    passwordSecret:
#      secretName: my-connect-user
#      password: my-connect-password-key
```

About the `bootstrapServers` from the above example yaml, the EventStreams CR populates the following fields
once it has started up:
```
$ oc describe EventStreams es-demo
...
Kafka Listeners:
  Addresses:
    Host:             es-demo-kafka-bootstrap.cp4i.svc
    Port:             9092
  Bootstrap Servers:  es-demo-kafka-bootstrap.cp4i.svc:9092
  Type:               plain
...
```

Apply the yaml using:
```
oc apply -f kafka-connect.yaml
```

Wait for the KafkaConnect to be ready, watch using:
```
oc get KafkaConnect eei-cluster -w
```

Describe the `KafkaConnect` and check that the Status section exists and the Conditions section
contains a condition with `Type` of `Ready` that has a `Status` of `True`:
```
$ oc describe KafkaConnect eei-cluster
...
Status:
  Conditions:
    Last Transition Time:  2022-06-30T14:10:07.392315758Z
    Status:                True
    Type:                  Ready
...
```

# Add connector to your Kafka Connect environment
Add connector for Postgres Debezium
- Navigate to the toolbox for the `es-demo` Event Streams runtime
- Click `Add connectors to your Kafka Connect environment`
- Click `View Catalog`.
- Find and click the following connectors and the click `Get connector` to download:
  - PostgreSQL (Debezium)
- Extract the PostgreSQL (Debezium) tgz into a dir named `my-plugins`
You should end up with a dir structure as follows:
![dir structure](./media/my-plugins-dir.png)

<!---
When using pre-release the base image in the Dockerfile may need updating. If so then
find the docker image used by the eei-cluster connect pod and change the FROM in the Dockerfile
to use that image. May need to change it from cp.icr.io to cp.stg.icr.io.
-->

Make sure the `FROM` in the Dockerfile is using `cp.icr.io/cp/ibm-eventstreams-kafka:11.1.1` rather than an older version.

Do a docker login to cp.icr.io using your entitlement key. I.e.:
```
docker login cp.icr.io -u ekey -p YOUR_EKEY_HERE
```

If running on non-amd64 (I.e. Mac with Arm):
```
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

Then from the dir above `my-plugins` run:
```
docker build -t eei-connect-cluster-image:latest .
```

Push the image to the cluster's image registry. Expose the registry and get the login details:
```
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

export IMAGE_REPO="$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')"
echo "IMAGE_REPO=${IMAGE_REPO}"

export DOCKER_REGISTRY_USER=image-bot
export DOCKER_REGISTRY_PASS="$(oc serviceaccounts get-token image-bot)"
echo "DOCKER_REGISTRY_USER=${DOCKER_REGISTRY_USER}"
echo "DOCKER_REGISTRY_PASS=${DOCKER_REGISTRY_PASS}"
docker login $IMAGE_REPO -u $DOCKER_REGISTRY_USER -p $DOCKER_REGISTRY_PASS
```

Tag the image and push to the cluster:
```
NAMESPACE=$(oc project -q)
docker tag eei-connect-cluster-image:latest $IMAGE_REPO/${NAMESPACE}/eei-connect-cluster-image:latest
docker push $IMAGE_REPO/${NAMESPACE}/eei-connect-cluster-image:latest
```

Confirm the image was pushed:
```
$ oc get imagestream eei-connect-cluster-image
NAME                        IMAGE REPOSITORY                                                                 TAGS     UPDATED
eei-connect-cluster-image   image-registry.openshift-image-registry.svc:5000/dan/eei-connect-cluster-image   latest   7 minutes ago
```

Get the image name:
```
echo "$(oc get imagestream eei-connect-cluster-image -o json | jq -r .status.dockerImageRepository):latest"
```

Edit the image property in the kafka-connect.yaml and re-apply.

Describe the `KafkaConnect` and check that the Status section shows the PostgresConnector (it will take a couple of minutes for this to happen):
```
$ oc describe KafkaConnect eei-cluster
...
Status:
  Conditions:
    Last Transition Time:  2023-01-13T10:27:35.609378911Z
    Status:                True
    Type:                  Ready
  Connector Plugins:
    Class:              io.debezium.connector.postgresql.PostgresConnector
    Type:               source
    Version:            1.2.0.Final
    Class:              org.apache.kafka.connect.mirror.MirrorCheckpointConnector
    Type:               source
    Version:            3.2.3
    Class:              org.apache.kafka.connect.mirror.MirrorHeartbeatConnector
    Type:               source
    Version:            3.2.3
    Class:              org.apache.kafka.connect.mirror.MirrorSourceConnector
    Type:               source
    Version:            3.2.3
  Label Selector:       eventstreams.ibm.com/kind=KafkaConnect,eventstreams.ibm.com/name=eei-cluster-connect,eventstreams.ibm.com/cluster=eei-cluster
  Observed Generation:  2
  Replicas:             1
  URL:                  http://eei-cluster-connect-api.cp4i.svc:8083
```

# Start Kafka Connect with the Postgres (Debezium) connector

Download the [example connector-postgres.yaml](kafkaconnect/connector-postgres.yaml). This is based on the one in
the Event Streams toolbox, which can be accessed by:
- Navigate to the toolbox for the `es-demo` Event Streams runtime
- Click `Start Kafka Connect with your connectors`
- Jump to the `Start a connector` section.
- View the example connector.yaml

The example includes comments describing each change, see the following:
```yaml
apiVersion: eventstreams.ibm.com/v1beta2
kind: KafkaConnector
metadata:
  name: eei-postgres
  labels:
    eventstreams.ibm.com/cluster: eei-cluster
spec:
  tasksMax: 1

  # This uses the Postgres Debezium plugin from the KafkaConnect
  class: io.debezium.connector.postgresql.PostgresConnector

  config:
    # These are connection details to the Postgres database setup by the prereqs.
    database.hostname: "postgresql"
    database.port: "5432"

    # The following credentials refer to the mounted secret and use the FileConfigProvider
    # from the KafkaConnect to extract properties from the properties file.
    database.dbname: "${file:/opt/kafka/external-configuration/postgres-connector-config/connector.properties:dbName}"
    database.user: "${file:/opt/kafka/external-configuration/postgres-connector-config/connector.properties:dbUsername}"
    database.password: "${file:/opt/kafka/external-configuration/postgres-connector-config/connector.properties:dbPassword}"

    # This is the prefix used for the topic created by this connector.
    database.server.name: "sor"

    # The Postgres Debezium connector has various ways of monitoring the Postgres database.
    #  We're using Postgres 10 which includes the `pgoutput` plugin by default.
    plugin.name: pgoutput

    # The following settings disable autocreation of a Postgres PUBLICATION and instead use
    # the one we created as part of the prereqs. This allows the Debezium Connector to
    # connect to Postgres with reduced privileges. For this connector to create a PUBLICATION
    # would require the connector to run with superuser privileges.
    publication.autocreate.mode: disabled
    publication.name: db_eei_quotes
```

Apply the yaml using:
```
oc apply -f connector-postgres.yaml
```

Wait for connector to be ready using:
```
oc get KafkaConnector eei-postgres -w
```

Find the connector pod and watch the logs:
```
CONNECTOR_POD=$(oc get pod -l eventstreams.ibm.com/cluster=eei-cluster --output=jsonpath={.items..metadata.name})
echo "CONNECTOR_POD=${CONNECTOR_POD}"
oc logs -f $CONNECTOR_POD
```

The following should appear in the logs (maybe after a minute):
```
2020-10-09 14:09:02,083 INFO Snapshot step 1 - Preparing (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,083 INFO Setting isolation level (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,083 INFO Opening transaction with statement SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY, DEFERRABLE; (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,186 INFO Snapshot step 2 - Determining captured tables (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,189 INFO Snapshot step 3 - Locking captured tables (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,190 INFO Waiting a maximum of '10' seconds for each table lock (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,228 INFO Snapshot step 4 - Determining snapshot offset (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,230 INFO Read xlogStart at '0/15E8B80' from transaction '569' (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,231 INFO Creating initial offset context (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,232 INFO Read xlogStart at '0/15E8B80' from transaction '569' (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,233 INFO Snapshot step 5 - Reading structure of captured tables (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,233 INFO Reading structure of schema 'db_dan_sor_eei' (io.debezium.connector.postgresql.PostgresSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,277 INFO Snapshot step 6 - Persisting schema history (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,277 INFO Snapshot step 7 - Snapshotting data (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,277 INFO 	 Exporting data from table 'public.quotes' (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,278 INFO 	 For table 'public.quotes' using select statement: 'SELECT * FROM "public"."quotes"' (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
2020-10-09 14:09:02,280 INFO 	 Finished exporting 0 records for table 'public.quotes'; total duration '00:00:00.003' (io.debezium.relational.RelationalSnapshotChangeEventSource) [debezium-postgresconnector-sor-change-event-source-coordinator]
```
And now the connector is monitoring the quotes table and creating events in the `sor.public.quotes` topic.

# The Quote Lifecycle Simulator
## Overview
The Quote Lifecycle Simulator application simulates changes to quotes by adding and modifying rows in the System Of Record database table, also known as the quotes table. See [the Quote Lifecycle Simulator readme](QuoteLifecycleSimulator/readme.md) for more details about the Quote Lifecycle Simulator application.

## Start/stop the Quote Lifecycle Simulator
Start up the Simulator by scaling up the deployment using:
```
oc scale deployment/quote-simulator-eei --replicas=1
```
Watch that the Simulator is inserting/updating rows using:
```
SIMULATOR_POD=$(oc get pod -l app=quote-simulator-eei --output=jsonpath={.items..metadata.name})
echo "SIMULATOR_POD=${SIMULATOR_POD}"
oc logs -f $SIMULATOR_POD
```
You should see output every second with logs something like:
```
2020/10/09 14:10:04 Found mobile claim with quoteID of 4e7e14fa-d242-4ad5-ae01-c554b7650430 and claimStatus of 1
2020/10/09 14:10:04 For claim with quoteID of 4e7e14fa-d242-4ad5-ae01-c554b7650430, updating claimStatus to 2
2020/10/09 14:10:04 No outstanding non-mobile claims found
2020/10/09 14:10:05 Found mobile claim with quoteID of 12abfe16-0c41-42a4-9edb-201f79ef05c2 and claimStatus of 1
2020/10/09 14:10:05 For claim with quoteID of 12abfe16-0c41-42a4-9edb-201f79ef05c2, updating claimStatus to 2
2020/10/09 14:10:05 No outstanding non-mobile claims found
2020/10/09 14:10:06 Found mobile claim with quoteID of 5a91ca69-0dd7-41ad-8d65-d7d4d8d55dea and claimStatus of 1
2020/10/09 14:10:06 For claim with quoteID of 5a91ca69-0dd7-41ad-8d65-d7d4d8d55dea, updating claimStatus to 2
2020/10/09 14:10:06 No outstanding non-mobile claims found
2020/10/09 14:10:06 Created new claim with id of c567cb9d-d296-4a41-96e0-a49d18d57c60
```
View the `sor.public.quotes` topic in Event Streams, new events should appear for every update to the database.

Stop the Simulator using:
```
oc scale deployment/quote-simulator-eei --replicas=0
```
Events should stop appearing in the `sor.public.quotes` topic.

# The Projection Claims application
Start the Projection Claims application using:
```
oc scale deployment/projection-claims-eei --replicas=1
```
Get the URL to open in your web browser using:
```
echo $(oc get route projection-claims-eei --template='https://{{.spec.host}}/getalldata')
```
Stop the Projection Claims application using:
```
oc scale deployment/projection-claims-eei --replicas=0
```

# Working directly with the System Of Record database
Setup some env vars
```
POSTGRES_NAMESPACE=cp4i
DB_POD=$(oc get pod -n ${POSTGRES_NAMESPACE} -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_NAME=$(oc get secret eei-postgres-replication-credential -o json | \
  jq -r '.data["connector.properties"]' | base64 --decode | grep dbName | awk '{print $2}')
```
Get a psql prompt for the database:
```
oc exec -n ${POSTGRES_NAMESPACE} -it $DB_POD -- psql -d ${DB_NAME}
```
Check the rows in the table:
```
db_uuid_sor_eei=# SELECT * FROM QUOTES;
               quoteid                |   source    |     name     |        email        | age |             address             | usstate | licenseplate | descriptionofdamage | claimstatus | claimcost
--------------------------------------+-------------+--------------+---------------------+-----+---------------------------------+---------+--------------+---------------------+-------------+-----------
 f7d2b638-0446-4ea9-a7bd-697bc2c95d52 | Mobile      | Andy Rosales | AndyR@mail.com      |  77 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Won't start         |           3 |
 427f2916-a746-4548-b9c6-8f344232e636 | Mobile      | Andy Rosales | AndyR@mail.com      |  74 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Cracked windscreen  |           4 |
 32e3b886-289e-45f3-9d0b-2e461b7235e4 | Mobile      | Nella Beard  | NBeard@mail.com     |  45 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Wheel fell off      |           3 |
 c2d88eb4-fcb9-4ac9-a5bc-0d23e2bdacb2 | Email       | Andy Rosales | AndyR@mail.com      |  40 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Dent in door        |           1 |
 dafcf44c-6948-4b20-a0e9-0d6a6a3f2de0 | Mobile      | Andy Rosales | AndyR@mail.com      |  21 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Dent in door        |           3 |
 ce31003c-77cd-4589-998a-ed74636b7453 | Mobile      | Nella Beard  | NBeard@mail.com     |  50 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Dent in door        |           2 |
 9ed6cb97-b7e7-42f7-bf7c-f4e073896444 | Web         | Ronny Doyle  | RonnyDoyle@mail.com |  43 | 790 Arrowhead Court, Portsmouth | VA      | WMC-9628     | Dent in door        |           7 |       300
 af52be30-306f-44d9-81cf-81db89995efc | Mobile      | Nella Beard  | NBeard@mail.com     |  60 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Won't start         |           4 |
 8675ec56-106b-45a1-bfd0-ed9a276e6a19 | Police      | Ronny Doyle  | RonnyDoyle@mail.com |  31 | 790 Arrowhead Court, Portsmouth | VA      | WMC-9628     | Wheel fell off      |           6 |       300
 1a629bd3-15c7-4f13-a702-871077f78281 | Mobile      | Nella Beard  | NBeard@mail.com     |  48 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Won't start         |           5 |       600
 82b475ab-d666-47f8-811a-a8106e664999 | Mobile      | Andy Rosales | AndyR@mail.com      |  59 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Wheel fell off      |           4 |
 ebe55243-c199-4c00-810d-22336f2137a6 | Email       | Andy Rosales | AndyR@mail.com      |  69 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Won't start         |           1 |
 72665b87-6493-4a2f-9443-6150c889b43f | Web         | Andy Rosales | AndyR@mail.com      |  30 | 9783 Oxford St., Duluth         | GA      | GWL3149      | Wheel fell off      |           1 |
 d0bd9c77-573d-425d-91c1-973b500cebe0 | Mobile      | Ronny Doyle  | RonnyDoyle@mail.com |  28 | 790 Arrowhead Court, Portsmouth | VA      | WMC-9628     | Cracked windscreen  |           3 |
 70374fc4-7910-496f-bbe3-a7b0819036cd | Call Center | Ronny Doyle  | RonnyDoyle@mail.com |  33 | 790 Arrowhead Court, Portsmouth | VA      | WMC-9628     | Cracked windscreen  |           7 |       800
 88953978-770c-4883-899b-fd5d4549d4d2 | Mobile      | Nella Beard  | NBeard@mail.com     |  39 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Dent in door        |           2 |
 d56e7c3d-a131-4995-bc7c-78a49e641f95 | Police      | Nella Beard  | NBeard@mail.com     |  71 | 8774 Inverness Dr., Janesville  | WI      | 787-YWR      | Cracked windscreen  |           6 |       300
(17 rows)
```
Delete the existing quotes.
```
db_uuid_sor_eei=# DELETE FROM QUOTES;
DELETE 17
```
Exit from the psql prompt:
```
db_uuid_sor_eei=# \q
```

# Reset the events for the sor.public.quotes topic
To remove all of the old events the whole `sor.public.quotes` topic can be deleted.
When further changes are made to the System Of Record table the Debezium connector
will recreate the topic.

To delete the topic.
- Navigate to the `es-demo` Event Streams instance from Navigator
- Click `Topics` on the left hand side
- Click the `...` menu for the `sor.public.quotes` topic
- Choose `Delete this topic`, then `Delete`

# REST endpoint

## ACE flow

### GET
![get sub flow](./media/rest-get-flow.png)

### POST
![post sub flow](./media/rest-post-flow.png)

The pipeline deploys an ACE integration server (`ace-rest-int-srv-eei`) that hosts the `/eventinsurance/quote` endpoint. The route of the integration server can be found with `oc get -n $NAMESPACE route ace-rest-int-srv-eei-https -ojsonpath='{.spec.host}'`. Make sure to use HTTPS.

Get api endpoint and auth:
```bash
export NAMESPACE=$(oc project -q)
export API_BASE_URL=$(oc -n $NAMESPACE get secret eei-api-endpoint-client-id -o jsonpath='{.data.api}' | base64 --decode)
export API_CLIENT_ID=$(oc -n $NAMESPACE get secret eei-api-endpoint-client-id -o jsonpath='{.data.cid}' | base64 --decode)
```

Example GET:
```bash
$ curl -k -H "X-IBM-Client-Id: ${API_CLIENT_ID}" "${API_BASE_URL}/quote?QuoteID=$QUOTE_ID"
```

Example POST:
```bash
curl -k "${API_BASE_URL}/quote" \
  -H "X-IBM-Client-Id: ${API_CLIENT_ID}" \
  -d '{
    "name": "Barack Obama",
    "email": "comments@whitehouse.gov",
    "age": "50",
    "address": "1600 Pennsylvania Avenue",
    "usState": "DC",
    "licensePlate": "EK 3333",
    "descriptionOfDamage": "420"
  }'
```

A successful request should return an HTTP 200 with a JSON body that contains the quote object with a quote id, e.g.:
```json
{
  "name": "Barack Obama",
  "email": "comments@whitehouse.gov",
  "age": "50",
  "address": "1600 Pennsylvania Avenue",
  "usState": "DC",
  "licensePlate": "EK 3333",
  "descriptionOfDamage": "420",
  "quoteid": "89f8c116-12d8-11eb-b21c-ac1e162c0000"
}
```
# DB Writer

## DB Writer Flow

![dbwriter flow](./media/db-writer-flow.png)

DB_writer bar file: Responsible for Reading messages from the Queue `Quote` and adding to the Postgres Database table `db_cp4i1_sor_eei`. The flow consists of MQ input node and Java compute node. MQ input node passes the messages to the java compute node in the flow which reads the messages from the queue after every second and adds them to the postgres table.

:information_source: Should the db writer fail to communicate with the SOR DB an exception will be thrown and after 99 unsuccessful retries (99 seconds) the message will be backed out to a backout queue `QuoteBO`.

# Testing the POST calls via APIC
Instructions to load test the POST call via APIC can be found [here](post-load-test-readme.md).

# Component Downtime Testing

Prereqs:
1. Configure kafka connectors
2. Call REST endpoint post & get

## I. Shutting down the db writer integration server

1. Delete the integration server:
    ```sh
    oc get integrationserver ace-db-writer-int-srv-eei -n $NAMESPACE -o json | jq -r 'del(.metadata.resourceVersion)' > ~/dbwriter.json
    oc -n $NAMESPACE delete integrationserver ace-db-writer-int-srv-eei
    ```
    The post call will succeed but the message won't be taken off the queue and won't be processed
2. Recreate integration server:
    ```sh
    oc apply -f ~/dbwriter.json
    ```
3. Test post and get (they should work now)

## II. Shutting down the queue manager

1. Delete the queue manager instance:
    ```sh
    oc get queuemanager mq-eei -n $NAMESPACE -o json | jq -r 'del(.metadata.resourceVersion)' > ~/eei-queuemanager.json
    oc -n $NAMESPACE delete queuemanager mq-eei
    ```
2. Test post call and you should receive an error that contains: `Failed to make a client connection to queue manager`. The get call will still return existing data if the projection claims db has already been populated.
3. Recreate queue manager and wait for phase to be running:
    ```sh
    oc apply -n $NAMESPACE -f ~/eei-queuemanager.json
    oc get queuemanager -n $NAMESPACE mq-eei
    ```
4. Test post and get (they should work now)

## III. Shutting down access to postgresql db

1. Setup some env vars:
    ```sh
    POSTGRES_NAMESPACE=cp4i
    DB_POD=$(oc get pod -n ${POSTGRES_NAMESPACE} -l name=postgresql -o jsonpath='{.items[].metadata.name}')
    DB_NAME=$(oc get secret eei-postgres-replication-credential -o json | \
    jq -r '.data["connector.properties"]' | base64 --decode | grep dbName | awk '{print $2}')
    ```
2. Get a psql prompt for the database:
    ```sh
    oc exec -n ${POSTGRES_NAMESPACE} -it $DB_POD -- psql -d ${DB_NAME}
    ```
3. To simulate the shut down:
    ```sql
    REVOKE ALL PRIVILEGES ON QUOTES FROM cp4i_sor_eei;
    REVOKE ALL PRIVILEGES ON QUOTES FROM cp4i_sor_replication_eei;
    ```
4. Post requests will succeed, however the new claim will not show up in the sor db or the projection claims db. Existing claims should still accessible with the get request but everything else will result in a 404. Make sure to restart the psql db within 99 seconds, otherwise the message will be put on the backout queue.
5. To restart psql, make sure you're exec'd into the database and run the following commands:
    ```sql
    GRANT ALL PRIVILEGES ON TABLE quotes TO cp4i_sor_eei;
    GRANT ALL PRIVILEGES ON TABLE quotes TO cp4i_sor_replication_eei;
    ```
6. Once the permissions have been restored, the new claim should show up in the psql db as well as the projection claims app.
