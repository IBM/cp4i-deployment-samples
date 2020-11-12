# Overview
This load test script will by default add 100 messages (can be increased or decreased as per requirement, check [running the script section](post-load-test-readme.md#running-the-test-script)) to the MQ Queue `Quote` by making REST calls via IBM API Connect. These messages will start appearing in the MQ queue named `Quotes` and the IntegrationServer `ace-db-writer-int-srv-eei` will read from the queue, one message per second and add them to the [System Of Record database](readme.md#working-directly-with-the-system-of-record-database).
<br /><br />

# Prerequisites
- Check both of the following ACE Integrations servers are ready and running:
    - `ace-rest-int-srv-eei` - Responsible for putting messages on the MQ Queue `Quote`.
    - `ace-db-writer-int-srv-eei` - Responsible for Reading messages from the Queue `Quote` and adding the to the Postgres Database table `db_cp4i_sor_eei`. The database table name might be different as it depends on the namespace. <br />
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
- Run the [load testing script](post-load-test.sh) with `NAMESPACE` parameter ([exported above](post-load-test-readme.md#prerequisites)) and the desired number of POST calls to be made (`TARGET_POST_CALLS` - if any value other than the default is required):
    ```
    export TARGET_POST_CALLS = <TARGET_POST_CALLS>
    ./post-load-test.sh -n $NAMESPACE -c $TARGET_POST_CALLS
    ```
- If `-n` is not provided the script will default to namespace `cp4i`.
    At the end of the script it will display:
    - Calls made in a second
    - Calls failed (if any) 
- If `-c` is not specified, the number of POST calls will default to `100`.
<br /><br />

# Checking the Queue
- Assuming that the Integration server `ace-db-writer-int-srv-eei` is running fine, you should be able to see messages appearing and disappearing from the `Quote` Queue in MQ Console on pressing the refresh icon. These messages are being added in the Postgres database table `db_cp4i_sor_eei` by `ace-db-writer-int-srv-eei`. The database table name might be different as it depends on the namespace.
<br /><br />

# Checking the logs for the Integration Server
- To verify that the integration server is picking up messages from the MQ queue, run the following commands:
    ```
    DB_WRITER_POD=$(oc get pod -l app.kubernetes.io/name=ace-db-writer-int-srv-eei --output=jsonpath={.items..metadata.name})
    echo "DB_WRITER_POD=${DB_WRITER_POD}"
    oc logs -f $DB_WRITER_POD
    ```
- The `DB_WRITER` pod should look like the following:
    ```
    2020-10-23 16:05:47.103100: Integration server has finished initialization. 
    2020-10-23T16:05:47.359Z Integration server is ready
    2020-10-23T16:05:47.359Z Gathering Metrics...
    2020-10-23T16:05:47.360Z Starting metrics gathering
    2020-10-23T16:05:47.360Z Processing metrics...
    2020-10-23T16:05:47.360Z ACE_ADMIN_SERVER_SECURITY is true
    2020-10-23T16:05:47.360Z Using CA Certificate folder /home/aceuser/adminssl
    2020-10-23T16:05:47.360Z Adding Certificate /home/aceuser/adminssl/ca.crt.pem to CA pool
    2020-10-23T16:05:47.360Z Adding Certificate /home/aceuser/adminssl/tls.crt.pem to CA pool
    2020-10-23T16:05:47.361Z Using provided cert and key for mutual auth
    2020-10-23T16:05:47.361Z ACE_ADMIN_SERVER_NAME is ace-db-writer-int-srv-eei
    2020-10-23T16:05:47.361Z Connecting to wss://localhost:7600/ for statistics gathering
    2020-10-23T16:05:47.361Z Cannot find admin-users.txt file, not retrieving session cookie
    2020-10-23 16:11:31.745     34 Rate throttling for one second
    2020-10-23 16:11:32.750     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:33.103     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:33.122     34 Rate throttling for one second
    2020-10-23 16:11:34.124     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:34.127     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:34.133     34 Rate throttling for one second
    2020-10-23 16:11:35.134     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:35.137     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:35.143     34 Rate throttling for one second
    2020-10-23 16:11:36.144     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:36.146     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:36.153     34 Rate throttling for one second
    2020-10-23 16:11:37.155     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:37.158     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:37.164     34 Rate throttling for one second
    2020-10-23 16:11:38.166     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:38.168     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    2020-10-23 16:11:38.175     34 Rate throttling for one second
    2020-10-23 16:11:39.176     34 Getting message from MQ queue to write in database
    2020-10-23 16:11:39.179     34 SQL String=INSERT INTO QUOTES(Name,EMail,Age,Address,USState,LicensePlate,descriptionOfDamage,QuoteID, Source) VALUES(?, ?, ?, ?, ? ,? ,? , ?, ?) RETURNING *
    ```
<br />

# Checking data in the System Of Record database
- To work with the database and check the data present, check [this section](readme.md#working-directly-with-the-system-of-record-database) in [Event Enabled Insurance Demo Readme](readme.md).
<br /><br />

# Stopping the test script
- To stop the script at any point after starting, press `ctrl` + `c` before it finishes execution.
