# Simulated Bookshop API

This API simulates an online bookshop to provide an example subject for AI-driven test generation in Cloud Pak for Integration.

The API is defined in the OpenAPI document [bookshop-v1.0.yaml](../bookshop-v1.0.yaml) which you can load directly into your API Management instance.

The implementation consists of a number of cooperating microservices:

- the _books-service_ maintains a catalogue of books
- the _customer-order-service_ manages customers and their orders
- the _services_ service hosts support services for the bookshop
- the _gateway_ service provides a simple front end

The standard deployment creates a separate instance of the books service to manage books in a particular language (French), and then the main service delegates French books to that instance, simply to display more interesting behaviours for analysis.

The gateway service exists to support a standalone deployment but to use the API as a subject for automated test generation you must invoke it through the API Management gateway.

## Build

Typically you don't need to build the API because there are pre-built images available from a public repository. If you want to change the source code, or your cluster cannot pull from the public repository, you can rebuild the images and push them to a repository of your choice using the supplied script, e.g.
```sh
$ ./scripts/build.sh 'acme.images.com/bookshop'
```

This uses the `docker` command to rebuild the images and push them to the specified repository (`acme.images.com/bookshop`) and you must already be logged in to the target registry (`acme.images.com`) for the push to succeed.

## Deploy

Prerequisites:

- You are logged in to an OCP 4.6+ cluster with admin privileges
- You have created a project/namespace in which to deploy
- The `oc` command is in your PATH

To deploy the latest, pre-built, public images:
```sh
$ ./scripts/deploy.sh
```

To deploy images you have created using the build script:
```sh
$ ./scripts/deploy.sh --tag <tag> <repository>
```

The `repository` must be the same one you specified to the build script, and the image `tag` will have been displayed in the build output, e.g.
```sh
$ ./scripts/deploy.sh --tag '2021-07-12-1731-my-branch' 'acme.images.com/bookshop'
```

There are additional options you can specify:

| Option                      | Description                                           | Default                                             |
| --------------------------- | ----------------------------------------------------- | --------------------------------------------------- |
| `-n, --namespace NAMESPACE` | An existing namespace in which to deploy              | The current namespace (project)                     |
| `--jaeger-endpoint URL`     | The URL of the Jaeger Collector                       | `http://jaeger-bookshop-collector:14268/api/traces` |
| `--language LANG`           | Two-letter ISO language code for the language service | `fr` (French)                                       |
| `-h, --help`                | Print option summary and exit                         |                                                     |

The deployment creates a route `bookshop-gateway` in the target namespace that serves both `/books` and `/customers` and you can use this to check that the deployment has succeeded. However, to use the API as a subject for automated test generation, you must load the OpenAPI document [bookshop-v1.0.yaml](../bookshop-v1.0.yaml) into your API Management instance and then access the bookshop through the API Management gateway.

## Use

You can generate a simulated workload using the [bookshop client](../client/README.md).

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
