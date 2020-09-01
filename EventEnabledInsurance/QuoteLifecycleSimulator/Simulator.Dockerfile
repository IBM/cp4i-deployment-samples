FROM golang:alpine AS builder

# build time args
ARG ARG_PG_HOST
ARG ARG_PG_USER
ARG ARG_PG_PASSWORD
ARG ARG_PG_DATABASE

# set runtime build args as env vars
ENV PG_HOST=$ARG_PG_HOST
ENV PG_USER=$ARG_PG_USER
ENV PG_PASSWORD=$ARG_PG_PASSWORD
ENV PG_DATABASE=$ARG_PG_DATABASE

# static env variables
ENV GO111MODULE=on
ENV PG_PORT=5432
ENV TICK_MILLIS=1000
ENV MOBILE_TEST_ROWS=10

# check go version
RUN go version

# create, change working directory and copy main.go to it
RUN mkdir -p /eei/go/
ADD main.go /eei/go/
WORKDIR /eei/go/

# copying and downloading go dependencies for main.go to be run
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .

# build the go image using main.go
# print the commands (-x)
# add a suffix 'eei' to the output
# print the names of packages as they are compiled (-v)
# copy output to /main directory
RUN CGO_ENABLED=0 GOOS=linux go build -a -v -x -installsuffix eei -o /main main.go

# using the built image
FROM scratch
COPY --from=builder /main /main
EXPOSE 5432
ENTRYPOINT ["/main", "--port", "5432", "--host", "127.0.0.1"]

# docker build . -f Simulator.Dockerfile -t simulator-eei --build-arg ARG_PG_USER=cp4i1_sor_eei --build-arg ARG_PG_PASSWORD=password --build-arg ARG_PG_DATABASE=db_cp4i1_sor_eei --build-arg ARG_PG_HOST=localhost