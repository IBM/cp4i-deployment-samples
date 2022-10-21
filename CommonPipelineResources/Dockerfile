# Used to run commands in an openshift pipeline. Supports:
# jq
# oc
# openssl
# runmqckm

FROM quay.io/openshift/origin-cli:latest as oc

FROM cp.icr.io/cp/ibm-mqadvanced-server-integration@sha256:0639d6d84c18ec8c477e47c29f604725f07b47ea50f23e4eaffae4e440d75fed as mq
USER root
RUN microdnf install --nodocs openssl wget zip
COPY --from=oc /usr/bin/oc /usr/local/bin
RUN wget -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
RUN chmod +x /usr/local/bin/jq
ENTRYPOINT []
USER 1001

# docker build . -t demo-cmd
# docker run -it demo-cmd bash
# docker run -it -v `pwd`/../products/bash/mq-im/mq-certs:/certs demo-cmd

# docker run demo-cmd bash -c 'ls; oc version'
