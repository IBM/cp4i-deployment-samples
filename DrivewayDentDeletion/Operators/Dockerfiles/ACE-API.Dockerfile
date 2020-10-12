FROM cp.icr.io/cp/appc/ace-server-prod@sha256:dd3c1e8d204b37775b792fc25a0bad4daba4fa35cd5aad996b29b1db63959baf
ENV MQCERTLABL=aceclient
COPY DrivewayDemo.bar /home/aceuser/initial-config/bars/
