FROM cp.icr.io/cp/appc/ace-server-prod@sha256:48569e3e1e219682e0ff5e24a810bf89317bb4ae961a02691c4dc206d74fce75
ENV MQCERTLABL=aceclient
COPY DrivewayDemo.bar /home/aceuser/initial-config/bars/
