FROM cp.stg.icr.io/cp/appc/ace-server-prod@sha256:d04fa579290896a8a9474382be3d2729580e16810beacfad8714e8df88794391
ENV MQCERTLABL=aceclient
COPY CrumpledV1.bar /home/aceuser/initial-config/bars/DrivewayDemo.bar
