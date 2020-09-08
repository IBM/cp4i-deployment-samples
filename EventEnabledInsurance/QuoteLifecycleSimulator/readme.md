# Overview
This directory contains the code for the Quote Lifecycle Simulator application.
This application simulates changes to quotes by adding and modifying rows in
the quotes table. The quotes go through the following states


They start at state 1 and move sequentially to 7. For this demo there are no exceptions/branches etc.
e.g. ‘Claim rejected’ except that for generated claims, only 1 out of 3 gets a
courtesy car.

Value | Claim Status
-----:| ------------
1     | Received
2     | Initially Approved
3     | *Optional* Courtesy Car Assigned
4     | Damage Being Assessed
5     | Claim Approved
6     | In the Workshop
7     | Car Repaired

# Implementation detail
Loop around. For each ‘Tick’:
1. Check for any claims with a source of 'Mobile' (this will be one from the API) and a state of <7. If any exist, pick one randomly and increase it's status by 1. All 'Mobile' claims go through status '4' (They all get a courtesy car)
2. If any other claims exist with status of <7, pick one randomly and increase it's status. If it's status becomes '3' then for 2 out of 3 claims, put it straight to '4'. I.e. no courtesy car needed.
3. During (1) and (2) if the status becomes ‘5’ assign a random claim cost to the claim.
4. Every 3rd tick, create a new claim with random user data and a 'non mobile' source and a status of 1 and a claim cost of null.

# To run locally
## Postgres setup
Ensure the database has the following type and table created:
```
CREATE TABLE IF NOT EXISTS QUOTES (
  QuoteID SERIAL PRIMARY KEY NOT NULL,
  Source VARCHAR(20),
  Name VARCHAR(100),
  EMail VARCHAR(100),
  Age INTEGER,
  Address VARCHAR(100),
  USState VARCHAR(100),
  LicensePlate VARCHAR(100),
  DescriptionOfDamage VARCHAR(100),
  ClaimStatus INTEGER,
  ClaimCost INTEGER
);
```

## Download the required packages
Get to use the network to update the required named packages and their dependencies (run this command from within the directory containing `Simulator.Dockerfile`):
```
go mod download
```

## Give access to postgres
Setup port forwarding from a local port to the postgres service on the cluster:
```
oc port-forward -n postgres service/postgresql 5432
```
## Run the application
Setup env vars to use the localhost and port from the port mapping and the required database name/user/password. Also choose how quickly to tick and how many mobile test rows to create if the database is empty (useful to get some mobile rows if the mobile app is not yet working):
```
export PG_HOST=localhost
export PG_PORT=5432
export PG_USER=admin
export PG_PASSWORD=password
export PG_DATABASE=sampledb
export TICK_MILLIS=1000
export MOBILE_TEST_ROWS=10
```
Run the application:
```
go run main.go
```

# User steps to build and deploy simulator pipelines
These steps will need to be documented in the demo docs:
- Fork/clone the repo
- Set `FORKED_REPO` to the URL for your repo and change the `<NAMESPACE>` to the namespace of 1-click install in which you want to deploy the simulator.
- Go into the `EventEnabledInsurance` directory
  ```
  oc project $NAMESPACE
  export BRANCH=main
  export FORKED_REPO=https://github.com/IBM/cp4i-deployment-samples.git

- Export the namespace by running the following command:
```
export namespace=<yourNamespace>
```
- Now run the prereqs script from the `EventEnabledInsurance` directory with the following command:
```
./prereqs.sh -n $namespace -b $BRANCH -r $FORKED_REPO
```
- The prereqs will set up the dependencies, secrets, the database and configures the pipeline to deploy the simulator app with 0 replicas.
- To scale up/down the replicas for the deployment:
```
oc scale deployment/quote-simulator-eei --replicas=<0/1>
```