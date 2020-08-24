# Overview
This dir is for a demo name "Event Enabled Insurance".

# Prerequisites
A [script](prereqs.sh) is provided to setup the prerequisits for this demo
and this script is automatically run as part of the 1-click demo preparation.
The script carries out the following:
- Installs Openshift pipelines from the ocp-4.4 channel.
- Creates a secret to allow the pipeline to pull from the entitled registry.
- Creates secrets to allow the pipeline to push images to the default project (`cp4i`).
- Creates a username and password for the dev (this is the namespace where the 1-click install ran in).
- Create a username for the postgres for this demo.
- Creates a database for the postfreg for this demo.
- Creates a `QUOTES` table in the database.
- Creates an ACE configuration and dynamic policy xml for postgres in the default namepsace `cp4i`.

# Information about `Quote Lifecycle Simulator`
The Quote Lifecycle Simulator application simulates changes to quotes by adding and modifying rows in the quotes table. See [the Quote Lifecycle Simulator readme](QuoteLifecycleSimulator/readme.md) for more details about the Quote Lifecycle Simulator application.