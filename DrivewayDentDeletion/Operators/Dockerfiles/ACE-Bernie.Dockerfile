FROM cp.icr.io/cp/appc/ace-server-prod@sha256:04bc376391a00ff1923d9122f93911b0f8e9700c7dda132f24676e383c0283cc
# TODO FROM cp.icr.io/cp/appc/ace-server-prod@sha256:dd3c1e8d204b37775b792fc25a0bad4daba4fa35cd5aad996b29b1db63959baf
COPY BernieV1.bar /home/aceuser/bars/
RUN ace_compile_bars.sh
