FROM cp.icr.io/cp/appc/ace-server-prod@sha256:04bc376391a00ff1923d9122f93911b0f8e9700c7dda132f24676e383c0283cc
COPY CrumpledV2.bar /home/aceuser/bars/
RUN ace_compile_bars.sh
