#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2018
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CLIENT_CERTIFICATE=mq-ddd-qm-dev-client

# TODO How to wait until the certificates are ready?

CLIENT_CERTIFICATE_SECRET=$(oc get certificate $CLIENT_CERTIFICATE -o json | jq -r .spec.secretName)
echo "CLIENT_CERTIFICATE_SECRET=${CLIENT_CERTIFICATE_SECRET}"

mkdir -p createcerts
rm createcerts/*

oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > createcerts/ca.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > createcerts/tls.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > createcerts/tls.key

cat createcerts/ca.crt > createcerts/application.pem
cat createcerts/tls.crt >> createcerts/application.pem
openssl pkcs12 -export -out createcerts/application.p12 -inkey createcerts/tls.key -in createcerts/application.pem -passout pass:password

# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -keydb -create -db application.jks -type jks -pw password'
# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -cert -add -db application.jks -file application.pem -pw password'
# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -cert -import -file application.p12 -pw password -target application.jks -target_pw password'
#
# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -keydb -create -db application.kdb -pw password -type cms -stash'
# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -cert -add -db application.kdb -file ca.crt -stashed'
# docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs ; runmqckm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient'

docker run -e LICENSE=accept -v `pwd`/createcerts:/certs --entrypoint bash ibmcom/mq -c 'cd /certs
runmqckm -keydb -create -db application.jks -type jks -pw password
runmqckm -cert -add -db application.jks -file application.pem -pw password
runmqckm -cert -import -file application.p12 -pw password -target application.jks -target_pw password
runmqckm -keydb -create -db application.kdb -pw password -type cms -stash
runmqckm -cert -add -db application.kdb -file ca.crt -stashed
runmqckm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient'

rm createcerts/ca.crt createcerts/tls.crt createcerts/application.pem createcerts/tls.key createcerts/application.p12 createcerts/application.rdb
