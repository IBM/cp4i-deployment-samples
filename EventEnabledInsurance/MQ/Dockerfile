FROM cp.icr.io/cp/ibm-mqadvanced-server-integration@sha256:615a3730ab42a57537fe65a617a13eac59e9c0858d5cfc9abeb8555a6b534225
RUN echo -e "\
DEFINE QLOCAL('Quote') \n\
DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) MCAUSER('mqm') \n\
SET CHLAUTH(ACE_SVRCONN) TYPE(BLOCKUSER) ACTION(REPLACE) USERLIST('nobody') \n\
alter qmgr CONNAUTH('') \n\
REFRESH SECURITY" > /etc/mqm/aceldap.mqsc
RUN cat /etc/mqm/aceldap.mqsc
