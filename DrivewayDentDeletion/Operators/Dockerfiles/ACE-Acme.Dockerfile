FROM cp.icr.io/cp/appc/ace-server-prod:12.0.7.0-r2-20221213-110429@sha256:9b679f0b1784d04e23796c25894763b26546b0966c93f82b504a260370e2be35
ENV MQCERTLABL=aceclient
COPY AcmeV1.bar /home/aceuser/initial-config/bars/
