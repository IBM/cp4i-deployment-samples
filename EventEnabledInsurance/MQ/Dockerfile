FROM cp.icr.io/cp/ibm-mqadvanced-server-integration@sha256:b03d83a14f5fc21b943ed23ca9c532bd564821b72d782864f7345d388334a197
RUN echo -e "\
DEFINE QLOCAL('Quote') \n\
DEFINE CHANNEL(ACE_SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) MCAUSER('mqm') \n\
SET CHLAUTH(ACE_SVRCONN) TYPE(BLOCKUSER) ACTION(REPLACE) USERLIST('nobody') \n\
alter qmgr CONNAUTH('') \n\
REFRESH SECURITY" > /etc/mqm/aceldap.mqsc
RUN cat /etc/mqm/aceldap.mqsc
