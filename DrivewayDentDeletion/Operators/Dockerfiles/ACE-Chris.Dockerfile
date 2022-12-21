FROM cp.icr.io/cp/appc/ace-server-prod:12.0.7.0-r1-20221125-161319@sha256:d51d0130663c65381a39f8eaeb316a0637c140ab6597099da06f145aecfbcebe
ENV MQCERTLABL=aceclient
COPY CrumpledV1.bar /home/aceuser/initial-config/bars/DrivewayDemo.bar
