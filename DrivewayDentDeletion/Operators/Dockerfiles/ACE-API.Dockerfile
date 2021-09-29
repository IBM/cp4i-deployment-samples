# Note if ibm-entitlement-key includes an auth for cp.stg.icr.io then this will be changed to cp.stg.icr.io:
FROM cp.icr.io/cp/appc/ace-server-prod@sha256:f7a74de7e5cd3d1d56cabde1c11b174b1be643f48c3bce63ab5f344495877052
ENV MQCERTLABL=aceclient
COPY DrivewayDemo.bar /home/aceuser/initial-config/bars/
