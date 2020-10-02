FROM cp.icr.io/cp/ibm-mqadvanced-server-integration@sha256:cfe3a4cec7a353e7496d367f9789dbe21fbf60dac46f127d288dda329560d13a
RUN echo -e "\
DEFINE QLOCAL('AccidentIn') \n\
DEFINE QLOCAL('AccidentOut') \n\
DEFINE QLOCAL('BumperIn') \n\
DEFINE QLOCAL('BumperOut') \n\
DEFINE QLOCAL('CrumpledIn') \n\
DEFINE QLOCAL('CrumpledOut') \n\
DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) MCAUSER('mqm') \n\
SET CHLAUTH(ACE_SVRCONN) TYPE(BLOCKUSER) ACTION(REPLACE) USERLIST('nobody') \n\
alter qmgr CONNAUTH('') \n\
REFRESH SECURITY" > /etc/mqm/aceldap.mqsc
RUN cat /etc/mqm/aceldap.mqsc
