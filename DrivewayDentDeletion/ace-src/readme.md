The source in PI-driveway-dent-deletion.zip is used to create the bar files in ../ace-acme,
../ace-api, ../ace-bernie, and ../ace-chris. Note that the current source has a couple of
issues that have been manually fixed in the bars and really need fixing in the source:
- The postgres credentials in the PostgresqlPolicy.policyxml are wrong
- The MQEndpointPolicy.policyxml needs to be moved from the `ACE_CP4I_Policies` to the `Default_Policies` policy group
- The version number for the V2 bars should be set to 2

These have been manually fixed in the bars:

For the main DrivewayDemo.bar extract using:
```
cd /Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-api
mkdir -p DrivewayDemo
cd DrivewayDemo
unzip ../DrivewayDemo.bar
mkdir appzip
cd appzip
unzip ../DrivewayDentDeletion.appzip
```
Then:
- Fix postgres credentials
- Move MQ setup to Default_Policies
- Edit flows to change "{ACE_CP4I_Policies}:MQEndpointPolicy" to "MQEndpointPolicy". See postQuote.subflow and META-INF/broker.zml

Then re-package using:
```
rm ../DrivewayDentDeletion.appzip
zip -r ../DrivewayDentDeletion.appzip *
cd ..
rm ../DrivewayDemo.bar
zip -r ../DrivewayDemo.bar ACE_CP4I_Policies/ Default_Policies/ DrivewayDentDeletion.appzip META-INF/
rm -rf DrivewayDemo
```

For each of the other bar files set some env vars, as follows for each:
```
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-acme
CHILD_DIR=AcmeAutoAccidents
BAR=AcmeV1
FLOW_NAME=Acme
VERSION=1
===
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-acme
CHILD_DIR=AcmeAutoAccidents
BAR=AcmeV2
FLOW_NAME=Acme
VERSION=2
===
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-bernie
CHILD_DIR=BernieBashedBumpers
BAR=BernieV1
FLOW_NAME=Bernie
VERSION=1
===
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-bernie
CHILD_DIR=BernieBashedBumpers
BAR=BernieV2
FLOW_NAME=Bernie
VERSION=2
===
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-chris
CHILD_DIR=ChrisCrumpledCars
BAR=CrumpledV1
FLOW_NAME=Chris
VERSION=1
===
BASE_DIR=/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/DrivewayDentDeletion/ace-chris
CHILD_DIR=ChrisCrumpledCars
BAR=CrumpledV2
FLOW_NAME=Chris
VERSION=2
```
For each bar run the following:
```
cd $BASE_DIR
mkdir -p $CHILD_DIR
cd $CHILD_DIR
unzip ../$BAR.bar
mkdir appzip
cd appzip
unzip ../${CHILD_DIR}.appzip

cat $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/PostgresqlPolicy.policyxml | sed "s#user=password#user=admin#g;" | sed "s#password=cP6GXUPoVDGu81Gq#password=password#g" > $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/PostgresqlPolicy.policyxml.bak
rm $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/PostgresqlPolicy.policyxml
mv $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/PostgresqlPolicy.policyxml.bak $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/PostgresqlPolicy.policyxml
mkdir $BASE_DIR/$CHILD_DIR/Default_Policies
cp $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/policy.descriptor $BASE_DIR/$CHILD_DIR/Default_Policies/
mv $BASE_DIR/$CHILD_DIR/ACE_CP4I_Policies/MQEndpointPolicy.policyxml $BASE_DIR/$CHILD_DIR/Default_Policies/

cat $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow.msgflow | sed "s#{ACE_CP4I_Policies}:MQEndpointPolicy#MQEndpointPolicy#g" > $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow.msgflow.bak
rm $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow.msgflow
mv $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow.msgflow.bak $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow.msgflow

cat $BASE_DIR/$CHILD_DIR/appzip/META-INF/broker.xml | sed "s#{ACE_CP4I_Policies}:MQEndpointPolicy#MQEndpointPolicy#g" > $BASE_DIR/$CHILD_DIR/appzip/META-INF/broker.xml.bak
rm $BASE_DIR/$CHILD_DIR/appzip/META-INF/broker.xml
mv $BASE_DIR/$CHILD_DIR/appzip/META-INF/broker.xml.bak $BASE_DIR/$CHILD_DIR/appzip/META-INF/broker.xml

cat $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow_Mapping.map | sed "s#assign value=\"1\"#assign value=\"${VERSION}\"#g" > $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow_Mapping.map.bak
rm $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow_Mapping.map
mv $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow_Mapping.map.bak $BASE_DIR/$CHILD_DIR/appzip/${FLOW_NAME}_Flow_Mapping.map

cd $BASE_DIR/$CHILD_DIR/appzip
rm ../${CHILD_DIR}.appzip
zip -r ../${CHILD_DIR}.appzip *
cd ..
rm ../${BAR}.bar
zip -r ../${BAR}.bar ACE_CP4I_Policies/ Default_Policies/ ${CHILD_DIR}.appzip META-INF/
cd $BASE_DIR
rm -rf ${CHILD_DIR}
```
