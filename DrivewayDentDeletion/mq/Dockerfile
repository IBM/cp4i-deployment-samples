FROM cp.icr.io/cp/icp4i/mq/ibm-mqadvanced-server-integration:9.1.4.0-r1-amd64
RUN echo -e "\
DEFINE QLOCAL('AccidentIn') \n\
DEFINE QLOCAL('AccidentOut') \n\
DEFINE QLOCAL('BumperIn') \n\
DEFINE QLOCAL('BumperOut') \n\
DEFINE QLOCAL('CrumpledIn') \n\
DEFINE QLOCAL('CrumpledOut') \n\
DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCIPH('ECDHE_RSA_AES_128_CBC_SHA256') SSLCAUTH(OPTIONAL) MCAUSER('mqm') \n\
SET CHLAUTH(ACE_SVRCONN) TYPE(BLOCKUSER) ACTION(REPLACE) USERLIST('nobody') \n\
REFRESH SECURITY" > /etc/mqm/aceldap.mqsc
RUN cat /etc/mqm/aceldap.mqsc
