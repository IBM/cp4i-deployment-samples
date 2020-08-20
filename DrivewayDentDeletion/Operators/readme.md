# Overview
This dir is for a demo name "Driveway Dent Deletion". The initial version of this
demo uses a Tekton pipeline to build images and deploy them for 4 App Connect
Integration Servers and 1 MQ server. Future versions of this demo will build
upon this.

# Prerequisites
A [script](prereqs.sh) is provided to setup the prerequisits for this demo
and this script is automatically run as part of the 1-click demo preparation.
The script carries out the following:
- Installs Tekton Pipelines v0.12.1
- Installs Tekton Triggers v0.5.0
- Creates a project to be used for the demo (default `cp4i`).
- Creates secrets to allow the pipeline to push images to the above project (default `cp4i`).
- Creates a secret to allow the pipeline to pull from the entitled registry
- Creates a username and password for each of the dev (this is the namespace where the 1-click install ran in) and test namespace.
- Creates a database for each of the user in each of the namespaces.
- Creates a `quotes` table in each database.
- Creates an operator group and product subscriptions.
- Releases the platform navigator and ace dashboard.

# User steps
These steps will need to be documented in the demo docs:
- Fork/clone the repo
- Run the script to create the dev pipeline, configured to use the forked repo. Set
`FORKED_REPO` to the URL for your repo and change the `<NAMESPACE>` to the namespace of 1-click install in which you want the pipeline to run.
  ```
  export NAMESPACE=<NAMESPACE>
  oc project $NAMESPACE
  export BRANCH=master
  export FORKED_REPO=https://github.com/IBM/cp4i-deployment-samples.git
  ./cicd-apply-dev-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH
  ```
- The above script `cicd-apply-dev-pipeline.sh` will create a dev pipeline in the `<NAMESPACE>` namepsace and will print the route to add to the webhook in the forked github repo.
- Run the script to create the test pipeline, configured to use the forked repo. Set
`FORKED_REPO` to the URL for your repo and change the `<NAMESPACE>` to the namespace of 1-click install in which you want the pipeline to run.
  ```
  export NAMESPACE=<NAMESPACE>
  oc project $NAMESPACE
  export BRANCH=master
  export FORKED_REPO=https://github.com/IBM/cp4i-deployment-samples.git
  ./cicd-apply-test-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH
  ```
- The above script `cicd-apply-test-pipeline.sh` will create a dev and test pipeline in the `<NAMESPACE>` namepsace and will print the route to add to the webhook in the forked github repo. (This will be the same route as above, but updated to point to a service for the test pipeline in the dev namespace).

# Pipelines
![Overview of aaS](../media/dev-pipeline.svg)
- Trigger: Whenever a commit is made to the forked repo it triggers the
  pipeline.
- Build tasks: Each of these tasks builds an images and pushes it to the cluster's local OpenShift Image Registry in the `<NAMESPACE>` namespace. The latest dockerfile and related files (bar files) are pulled from the forked git repo.
- Deploy and wait to dev tasks: Each of these tasks invokes the deployments using the newly built image, initially in the `<NAMESPACE>` and then in the `<NAMESPACE>-ddd-test` namespace.
- Test E2E API test task: This task tests the end-to-end API using curl commands to make a POST and a GET to the postgres database, initially in the `<NAMESPACE>` namespace and then finally as a last step in the `<NAMESPACE>-ddd-test` namespace after all deployments have been done successfully in the next step.
- Image Push to test task - If the test task succeeds, then each of this task pushes the images built in the `<NAMESPACE>` namespace to the `<NAMESPACE>-ddd-test` namespace.
