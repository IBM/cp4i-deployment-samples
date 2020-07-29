FROM cp.icr.io/cp/icp4i/mq/ibm-mqadvanced-server-integration:9.1.4.0-r1-amd64
RUN echo -e "\
DEFINE QLOCAL('AccidentIn') DEFPSIST(YES)\n\
DEFINE QLOCAL('AccidentOut') DEFPSIST(YES)\n\
DEFINE QLOCAL('BumperIn') DEFPSIST(YES)\n\
DEFINE QLOCAL('BumperOut') DEFPSIST(YES)\n\
DEFINE QLOCAL('CrumpledIn') DEFPSIST(YES)\n\
DEFINE QLOCAL('CrumpledOut') DEFPSIST(YES)\n\
DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) MCAUSER('mqm') \n\
SET CHLAUTH(ACE_SVRCONN) TYPE(BLOCKUSER) ACTION(REPLACE) USERLIST('nobody') \n\
alter qmgr CONNAUTH('') \n\
REFRESH SECURITY" > /etc/mqm/aceldap.mqsc
RUN cat /etc/mqm/aceldap.mqsc
