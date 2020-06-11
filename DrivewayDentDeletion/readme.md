# Prerequisites
These will be automatically created as part of the 1-click demo preparation:
- Tekton Pipelines v0.12.1 installed on cluster
- Tekton Triggers v0.5.0 installed on cluster
- An instance of Postgres 9.6
- A DrivewayDentDeletion database with required tables
- Secret for ACE API to connect to MQ and Postgres
- Secret for MQ to connect to Acme's/Bernie's/Chris' ACE
- Secret for Acme's/Bernie's/Chris' ACE to connect to MQ

# User steps
These steps will need to be documented in the demo docs:
- Fork/clone the repo
- Apply yaml to create the pipeline, configured to use the forked repo
- Run the command `oc expose svc el-main-trigger` to expose the event listener service
- Run the command `echo "$(oc  get route el-main-trigger --template='http://{{.spec.host}}')"` to get the url for the trigger
- Add the trigger url to the repo as a webhook, which triggers an initial run of the pipeline.

# Pipelines
![Overview of aaS](media/dev-pipeline.svg)
- Trigger: Whenever a commit is made to the forked repo it triggers the
  pipeline.
- Build tasks: Each of these tasks builds an images and pushes it to the cluster's local OpenShift Image Registry. The latest dockerfile and related files (bar files) are pulled from the forked git repo.
- Deploy to dev tasks: Each of these tasks invokes helm to deploy/upgrade the deployments using the newly built image.
- Await dev rollout: Waits for the deployments to complete rolling out so the new images are running on all replicas. Note that for this stage to complete the liveness probe for the newly deployed images has passed.
- Test dev: Runs a rudimentary test to ensure the new deployments are working.
