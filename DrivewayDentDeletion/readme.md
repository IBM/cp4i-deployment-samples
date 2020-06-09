# Prerequisites
These are installed automatically as part of the 1-click demo preparation:
- An instance of Postgres 9.6
- A DrivewayDentDeletion database with required tables
- Secret for ACE API to connect to MQ and Postgres
- Secret for MQ to connect to Acme's/Bernie's/Chris' ACE

# User steps:
- Fork/clone the repo
- Apply yaml to create the trigger
- Run a command to get the url for the trigger
- Add the trigger url to the repo as a webhook

# Dev Pipeline
![Overview of aaS](media/dev-pipeline.svg)
- Trigger: Whenever a commit is made to the forked repo it triggers the pipeline which runs using the newly committed state from the repo.
- Build: Builds all of the images and pushes them to the cluster's local OpenShift Image Registry.
- Deploy to dev: Invokes helm to deploy/upgrade each of the deployments using the newly built images.
- Await dev roolout: Waits for the deployments to complete rolling out so the new images are running on all replicas. Note that for this stage to complete the liveness probe for the newly deployed images has passed.
- Test dev: Runs a rudimentary test to ensure the new deployments are working.
