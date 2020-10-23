# Overview
This load test script will add 1000 messages to the MQ Queue `Quote` by making REST calls via IBM API Connect. These messages will start appearing in the MQ queue named `Quotes` and the IntegrationServer `ace-db-writer-int-srv-eei` will read from the queue, one message per second and add them to the [System Of Record database](readme.md#working-directly-with-the-system-of-record-database).
<br /><br />

# Prerequisites
- Check both of the following ACE Integrations servers are ready and running:
    - `ace-rest-int-srv-eei` - Responsible for putting messages on the MQ Queue `Quote`.
    - `ace-db-writer-int-srv-eei` - Responsible for Reading messages from the Queue `Quote` and adding the to the Postgres Database table `db_cp4i1_sor_eei`.<br />
    You can do so by checking the presence and status of the mentioned IntegrationServers by running the following commands:
    ```
    export NAMESPACE=<NAMESPACE>
    oc get IntegrationServers -n $NAMESPACE
    ```
    Here the `<NAMESPACE>` is the namespace where the 1-click install initially ran.

- Check that the MQ queue manager is deployed and in `Running` phase:
    ```
    oc get QueueManager -n $NAMESPACE mq-eei
    ```
- Check that the MQ queue manager pod is `Ready` and in `Running` state using the following command:
     ```
    oc get pods -n $NAMESPACE $(oc get pods -n $NAMESPACE | grep mq-eei-ibm-mq | awk '{print $1}')
    ```
- Open MQ console to check the Queue called `Quote` under Queue Manager `eei`. To get the MQ console URL using the following command:
    ```
    HOST=https://$(oc get routes -n ${NAMESPACE} mq-eei-ibm-mq-web -o json | jq -r '.spec.host')/ibmmq/console/
    echo $HOST
    ```
    You can also access the MQ console using the Platform Navigator
- The MQ Queue `Quote` would initially be empty.
<br /><br />

# Running the test script
- Run the [load testing script](post-load-test.sh) with `NAMESPACE` ([exported above](post-load-test-readme.md#prerequisites)) parameter `-n`:
    ```
    ./post-load-test.sh -n $NAMESPACE
    ```
    If `-n` not provided the script will default to namespace `cp4i`.
    At the end of the script it will display:
    - Calls made in a second
    - Calls failed (if any) 
<br /><br />

# Checking the Queue
- Assuming that the Integration server `ace-db-writer-int-srv-eei` is running fine, you should be able to see messages appearing disappearing from the `Quote` Queue in MQ Console on pressing the refresh icon. These messages are being added in the Postgres database table `db_cp4i1_sor_eei` by `ace-db-writer-int-srv-eei`.
<br /><br />
# Checking the logs for the Integration Server
- To verify that the integration server is picking up messages from the MQ queue, run the following commands:
    ```
    DB_WRITER_POD=$(oc get pod -l app.kubernetes.io/name=ace-db-writer-int-srv-eei --output=jsonpath={.items..metadata.name})
    echo "DB_WRITER_POD=${DB_WRITER_POD}"
    oc logs -f $DB_WRITER_POD
    ```
<br />

# Checking data in the System Of Record database
- To work with the database and check the data present, check [this section](readme.md#working-directly-with-the-system-of-record-database) in [Event Enabled Insurance Demo Readme](readme.md).
<br /><br />

# Stopping the test script
- To stop the script at any point after starting, press `ctrl` + `c` before it finishes execution.