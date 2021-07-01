# Synthetic Bookshop API

This API simulates an online bookshop to provide OpenTracing data for the API TestGen project.

The API is defined in the OpenAPI document [bookshop-v1.0.yaml](./bookshop-v1.0.yaml).

The implementation consists of a number of cooperating microservices:

- the _books-service_ maintains a catalogue of books
- the _book-lang-service_ is similar but restricted to a particular language
  - we use French (FR) by default
  - the books service delegates books in that language to the language service
- the _customer-order-service_ manages customers and their orders
- the _services_ service hosts support services for the bookshop

## Build

You must specify a target repository:

```sh
$ ./scripts/build.sh 'acme.images.com/bookshop'
```

You must be logged in to the registry for the push to succeed.

## Deploy

Prerequisites:

- You are logged in to an OCP 4.x cluster with admin privileges
- You have created a project/namespace in which to deploy

You can deploy a specific build identified by an image tag; if you built locally (above) then the script will have printed the tag at the end. In this case you can also specify an alternative repository for the images, which is probably the same one you specified in the build:

```
$ ./scripts/deploy.sh --tag <tag> [options] [repository]
```

There are additional options you can specify:

| Option                      | Description                                           | Default                                             |
| --------------------------- | ----------------------------------------------------- | --------------------------------------------------- |
| `-n, --namespace NAMESPACE` | An existing namespace in which to deploy              | `cp4i-bookshop`                                     |
| `--jaeger-endpoint URL`     | The URL of the Jaeger Collector                       | `http://jaeger-bookshop-collector:14268/api/traces` |
| `--language LANG`           | Two-letter ISO language code for the language service | `fr` (French)                                       |
| `-h, --help`                | Print option summary and exit                         |                                                     |

The deployment creates a route `bookshop-gateway` in the target namespace that serves both `/books` and `/customers`.

## Use

You can generate a random workload from the script [bookshop-client.sh](./../client/python/client/bookshop_client.py).

Resources are stored in memory so don't survive restarts.

### Authentication

The API requires an authentication/authorization header of the form:

```
Authorization: <token>
```

where the `token` is a base64-encoded string of the form:

```
<username>:<password>
```

Both the `username` and the `password` can be anything but if the `username` is `admin` then the call is assigned administrator privileges, required to update the bookshop (`POST`, `PUT`, `DELETE`). There are no real user accounts so names and passwords are not checked.

## Trace

To get traces out of the API you must create a Jaeger instance and specify the URL of the Collector in your deployment.

The full instructions to create an instance using the Red Hat OpenShift Jaeger operator in Operator Hub are [here](https://docs.openshift.com/container-platform/4.6/jaeger/jaeger_install/rhbjaeger-installation.html).

### Manual setup

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
  namespace:
spec:
  strategy: production
  storage:
    type: elasticsearch
  ingress:
    security: oauth-proxy
```

This will place the Jaeger Collector at `http://jaeger-bookshop-collector:14268/api/traces` which is the default, so you only need to specify the collector endpoint in the deployment if you change the instance name, or create it in a different namespace.
