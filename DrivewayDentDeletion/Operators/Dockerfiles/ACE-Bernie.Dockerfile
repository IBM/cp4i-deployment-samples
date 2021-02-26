FROM cp.icr.io/cp/appc/ace-server-prod@sha256:b218a2daec93b8e4555f58a3fd658c3d7b30893b6bff69ec92f81d946c4d1ab3
ENV MQCERTLABL=aceclient
COPY BernieV1.bar /home/aceuser/initial-config/bars/
