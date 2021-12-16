# Note if ibm-entitlement-key includes an auth for cp.stg.icr.io then this will be changed to cp.stg.icr.io:
FROM cp.icr.io/cp/appc/ace-server-prod@sha256:f31b9adcfd4a77ba8c62b92c6f34985ef1f2d53e8082f628f170013eaf4c9003
ENV MQCERTLABL=aceclient
COPY DrivewayDemo.bar /home/aceuser/initial-config/bars/
