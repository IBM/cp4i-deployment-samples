# Note if ibm-entitlement-key includes an auth for cp.stg.icr.io then this will be changed to cp.stg.icr.io:
FROM cp.icr.io/cp/appc/ace-server-prod@sha256:0214e90f08f57574f02b39d847180f7502cc1c17fe93a31829f11f9b8a7794d1
ENV MQCERTLABL=aceclient
COPY AcmeV1.bar /home/aceuser/initial-config/bars/
