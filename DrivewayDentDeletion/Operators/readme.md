# Overview
This dir is for a demo name "Driveway Dent Deletion". The initial version of this
demo uses a Tekton pipeline to build images and deploy them for 4 App Connect
Integration Servers and 1 MQ server. Future versions of this demo will build
upon this.

# Prerequisites
A [script](prereqs.sh) is provided to setup the prerequisits for this demo
and this script is automatically run as part of the 1-click demo preparation.
The script sets up the following:
- Installs Tekton Pipelines v0.12.1
- Installs Tekton Triggers v0.5.0
- Creates a project to be used for the demo (default `cp4i`).
- Creates secrets to allow the pipeline to push images to the above project (default `cp4i`).
- Creates a secret to allow the pipeline to pull from the entitled registry
- Creates a `quotes` table in the Postgres sampledb database

# User steps
These steps will need to be documented in the demo docs:
- Fork/clone the repo
- Apply yaml to create the pipeline, configured to use the forked repo. Set
`FORKED_REPO` to the URL for your repo and change the `<NAMESPACE>` to the namespace of 1-click install in which you want the pipeline to run.
  ```
  export NAMESPACE=<NAMESPACE>
  oc project $NAMESPACE
  export BRANCH=master
  export FORKED_REPO=https://github.com/IBM/cp4i-deployment-samples.git
  ./cicd-apply-pipeline.sh -n $NAMESPACE -r $FORKED_REPO -b $BRANCH
  ```
- The above script `cicd-apply-pipeline.sh` will print out the trigger URL and the next step.

# Pipelines
![Overview of aaS](../media/dev-pipeline.svg)
- Trigger: Whenever a commit is made to the forked repo it triggers the
  pipeline.
- Build tasks: Each of these tasks builds an images and pushes it to the cluster's local OpenShift Image Registry in the `<NAMESPACE>` namespace. The latest dockerfile and related files (bar files) are pulled from the forked git repo.
- Deploy and wait to dev tasks: Each of these tasks invokes the deployments using the newly built image, initially in the `<NAMESPACE>` and then in the `<NAMESPACE>-ddd-test` namespace.
- Test E2E API test task: This task tests the end-to-end API using curl commands to make a POST and a GET to the postgres database, initially in the `<NAMESPACE>` namespace and then finally as a last step in the `<NAMESPACE>-ddd-test` namespace after all deployments have been done successfully in the next step.
- Image Push to test task - If the test task succeeds, then each of this task pushes the images built in the `<NAMESPACE>` namespace to the `<NAMESPACE>-ddd-test` namespace.
