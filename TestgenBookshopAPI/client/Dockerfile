FROM registry.access.redhat.com/ubi8/python-39
ENV HOME=/opt/app-root/src
RUN mkdir -p ${HOME}
WORKDIR ${HOME}
COPY . ${HOME}/
# Install Python client requirements
RUN pip3 install --no-cache-dir -r ${HOME}/requirements.txt
ENTRYPOINT ["scripts/bookshop-client.sh"]
