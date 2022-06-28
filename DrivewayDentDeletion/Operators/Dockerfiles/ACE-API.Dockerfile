# Note if ibm-entitlement-key includes an auth for cp.stg.icr.io then this will be changed to cp.stg.icr.io:
FROM cp.icr.io/cp/appc/ace-server-prod@sha256:48569e3e1e219682e0ff5e24a810bf89317bb4ae961a02691c4dc206d74fce75
ENV MQCERTLABL=aceclient
COPY DrivewayDemo.bar /home/aceuser/initial-config/bars/
