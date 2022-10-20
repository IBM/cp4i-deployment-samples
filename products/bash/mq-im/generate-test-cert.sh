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

# TODO Different cert for ddd dev/test and for eei
CLIENT_CERTIFICATE=qm-mq-ddd-qm-dev-client

# TODO How to wait until the certificates are ready?

CLIENT_CERTIFICATE_SECRET=$(oc get certificate $CLIENT_CERTIFICATE -o json | jq -r .spec.secretName)
echo "CLIENT_CERTIFICATE_SECRET=${CLIENT_CERTIFICATE_SECRET}"

mkdir -p mq-certs
rm mq-certs/*

oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > mq-certs/ca.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > mq-certs/tls.crt
oc get secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > mq-certs/tls.key

cat mq-certs/ca.crt > mq-certs/application.pem
cat mq-certs/tls.crt >> mq-certs/application.pem
openssl pkcs12 -export -out mq-certs/application.p12 -inkey mq-certs/tls.key -in mq-certs/application.pem -passout pass:password

docker run -e LICENSE=accept -v `pwd`/mq-certs:/certs --entrypoint bash ibmcom/mq -c 'cd /certs
runmqckm -keydb -create -db application.kdb -pw password -type cms -stash
runmqckm -cert -add -db application.kdb -file ca.crt -stashed
runmqckm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient'

rm mq-certs/ca.crt mq-certs/tls.crt mq-certs/tls.key mq-certs/application.pem mq-certs/application.p12 mq-certs/application.rdb
