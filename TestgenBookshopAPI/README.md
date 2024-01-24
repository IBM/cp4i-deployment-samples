# Simulated Bookshop API

This API simulates an online bookshop to provide an example subject for AI-driven test generation in Cloud Pak for Integration.

The API is defined in the OpenAPI document [bookshop-v1.0.yaml](./bookshop-v1.0.yaml).

Complete the following steps to deploy the API.

## Prerequisites

- You are logged in to an OCP 4.6+ cluster with admin privileges
- You have created a project/namespace in which to deploy
- You have installed Cloud Pak for Integration into the namespace and created the following instances:
  - Platform Navigator
  - API Management
- The `oc` command is in your PATH

## Setup Jaeger tracing

AI Test Generation examines OpenTracing traces emitted by the API to identify behaviours not covered by tests so you must create a Jaeger tracing instance and specify the URL of the Collector in your deployment.

The full instructions to create an instance using the Red Hat OpenShift Jaeger operator in Operator Hub are [here](https://docs.openshift.com/container-platform/4.6/jaeger/jaeger_install/rhbjaeger-installation.html).

In summary:

1. Install the Elasticsearch operator to all namespaces (cluster scoped)
2. Install the Red Hat OpenShift Jaeger operator to all namespaces (cluster scoped)
3. Create a Jaeger instance in your target namespace:
   - Name it `jaeger-bookshop`
   - Choose the `production` strategy
   - Set the storage type to `elasticsearch`

You can use this YAML for step 3, having set the namespace appropriately:

```yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-bookshop
spec:
  strategy: production
  storage:
    type: elasticsearch
  ingress:
    security: oauth-proxy
```

This will place the Jaeger Collector at `http://jaeger-bookshop-collector:14268/api/traces` which is the default, so you only need to specify the collector endpoint in the deployment if you change the instance name, or create it in a different namespace.

## Deploy the Bookshop service

To deploy the latest, pre-built, service images into your selected namespace:
```sh
$ ./service/scripts/deploy.sh -n <namespace>
```

If you omit the namespace option it will deploy to the current namespace.

If your Jaeger Collector endpoint is different from the default you must specify it in the command:
```sh
$ ./service/scripts/deploy.sh -n <namespace> --jaeger-endpoint 'http://jaeger-bookshop-collector:14268/api/traces'
```

If you need to rebuild the images for any reason, see the service [README](./service/README.md).

## Define and publish the Bookshop API

Add the Bookshop API to your API Management instance by importing the OpenAPI document [bookshop-v1.0.yaml](./bookshop-v1.0.yaml). The document includes the necessary configuration so you can go straight on to Activate and Publish the API. This will make the API reachable through the API Management gateway.

For more information about importing an API definition, refer to the documentation for [IBM API Connect](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=cad-adding-rest-api-by-importing-openapi-definition-file).

## Simulate a Production workload

To simulate a production workload and create a collection of traces for analysis, use the Bookshop Client image:
```sh
$ docker run -it --rm icr.io/integration/bookshop-api/client --url <gateway-url> --count 5000
```

You will find the bookshop gateway URL on the **Endpoint** tab in the API Management UI.

The `count` determines the number of requests, and each request emits a trace.

If the client cannot verify the gateway certificate you can either supply a certificate or disable verification: for these and other command-line options, see the client [README](./client/README.md).
