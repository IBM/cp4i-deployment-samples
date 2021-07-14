# Bookshop client

A bookshop client to call the bookshop API to add some sample traces.

## Build

You must specify a target repository for the [build script](scripts/build.sh):

```sh
$ ./scripts/build.sh 'acme.images.com/client'
```

You must be logged in to the registry for the push to succeed.

## Creating traces using docker image

### Pull the bookshop client image:

```bash
docker pull icr.io/integration/bookshop-api/client:latest
```

### Run the bookshop client docker image to create samples traces:

```bash
docker run -it --rm icr.io/integration/bookshop-api/client:latest --url ${ENDPOINT_URL} --count ${NUMBER_OF_TRACES_TO_CREATE} -v
```

This will create the required number of traces and then remove the container.

You can change the repository, image name and the tag if it was built and pushed manually in the [build step](#build). You must be logged in to the registry for the pull to succeed.

## Creating traces using the `bookshop-client` script

You can manually run the [bookshop-client.sh](scripts/bookshop-client.sh) script to create random workloads.

Prerequisites:

- Bookshop API services deployed. See [this guide](../service/README.md#deploy)
- Python 3.9 or above installed
- Packages in [requirements.txt](requirements.txt) installed

```bash
./scripts/bookshop-client.sh --url ${ENDPOINT_URL} --count ${NUMBER_OF_TRACES_TO_CREATE} -v
```

## Options for creating traces

| Option                          | Description                                            |
| ------------------------------- | ------------------------------------------------------ |
| `--url URL`                     | The Jaeger bookshop gateway URL                        |
| `--client-id CLIENT_ID`         | APIC catalog client id                                 |
| `--books-url BOOKS_URL`         | Books endpoint (overrides the bookshop gateway URL)    |
| `--customers-url CUSTOMER_URL`  | Customer endpoint (overrides the bookshop gateway URL) |
| `--count COUNT`                 | Number of requests (default=1)                         |
| `--config-file CONFIG_FILE`     | Configuration file                                     |
| `--database-file DATABASE_FILE` | Books database file                                    |
| `--cert-verify FILE`            | Certificate file (.pem) for HTTPS verification         |
| `--no-verify`                   | Disable HTTPS verification                             |
| `--no-async`                    | Disable asynchronous behaviour in the API              |
| `--no-loops`                    | Disable looping behaviour in the API                   |
| `--seed SEED`                   | Random number SEED to reproduce a request sequence     |
| `-v` or `--verbose`             | Show request summary                                   |
| `-vv` or `--debug`              | Show request detail                                    |
| `-h` or `--help`                | Available usage and options                            |
