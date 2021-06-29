FROM node:16
ARG SRC_DIR=missing
RUN mkdir /src
RUN mkdir /libs
COPY src/${SRC_DIR} /src
COPY src/libs /libs
WORKDIR /src
RUN for d in $(find /src /libs -name node_modules -prune -o -name package.json -print); do cd $(dirname $d); npm install; cd -; done
EXPOSE 5000
CMD ["node", "-r", "./tracing.js", "app.js"]
