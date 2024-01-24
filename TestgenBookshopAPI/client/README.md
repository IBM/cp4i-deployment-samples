# Bookshop client

Sends a simulated workload to the Bookshop API to create sample traces.

This requires that you have deployed the bookshop services as described in the service [README](../service/README.md).

## Building the client

Typically you don't need to build the client because there is a pre-built image available from a public repository. If you want to change the source code, or you cannot pull from the public repository, you can rebuild the image and push it to a repository of your choice using the supplied script, e.g.
```sh
$ ./scripts/build.sh 'acme.images.com/bookshop'
```

This uses the `docker` command to rebuild the client image and push it to the specified repository (`acme.images.com/bookshop`) and you must already be logged in to the target registry (`acme.images.com`) for the push to succeed.

You can also run the client directly, and avoid using Docker, if you have an appropriate version of Python installed.

## Simulating a workload using the client image

To send 5000 requests using the pre-built client image:
```sh
$ docker run -it --rm icr.io/integration/bookshop-api/client --url <gateway-url> --count 5000
```

This will pull the latest build of the image when it is called for the first time. You can specify a different image path and tag if you built your own version of the client in the [build step](#building-the-client) in which case you must be logged in to the registry to pull the image.

The gateway URL must be the endpoint for your bookshop deployment.

## Simulating a workload using the `bookshop-client` script

As an alternative, you can run the [bookshop-client.sh](./scripts/bookshop-client.sh) script directly to simulate a workload.

Prerequisites:

- Python 3.9 or above installed
- Packages in [requirements.txt](requirements.txt) installed

To send 5000 requests using the client script:
```sh
$ ./scripts/bookshop-client.sh --url <gateway-url> --count 5000
```

## Client options

| Option                          | Description                                            |
| ------------------------------- | ------------------------------------------------------ |
| `--url URL`                     | The bookshop gateway URL                               |
| `--books-url BOOKS_URL`         | Books endpoint (overrides the bookshop gateway URL)    |
| `--customers-url CUSTOMER_URL`  | Customer endpoint (overrides the bookshop gateway URL) |
| `--count COUNT`                 | Number of requests (default=1)                         |
| `--client-id CLIENT_ID`         | APIC catalog client id                                 |
| `--config-file CONFIG_FILE`     | Configuration file                                     |
| `--database-file DATABASE_FILE` | Books database file                                    |
| `--cert-verify FILE`            | Certificate file (.pem) for HTTPS verification         |
| `--no-verify`                   | Disable HTTPS verification                             |
| `--no-async`                    | Disable asynchronous behaviour in the API              |
| `--no-loops`                    | Disable looping behaviour in the API                   |
| `--seed SEED`                   | Random number SEED to reproduce a request sequence     |
| `-v, --verbose`                 | Show request summary                                   |
| `-vv, --debug`                  | Show request detail                                    |
| `-h, --help`                    | Available usage and options                            |
