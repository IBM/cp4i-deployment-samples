# Note if ibm-entitlement-key includes an auth for cp.stg.icr.io then this will be changed to cp.stg.icr.io:
FROM cp.icr.io/cp/appc/ace-server-prod@sha256:d04fa579290896a8a9474382be3d2729580e16810beacfad8714e8df88794391
COPY DB-WRITER.bar /home/aceuser/initial-config/bars/
