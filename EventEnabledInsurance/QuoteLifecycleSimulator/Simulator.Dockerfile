FROM golang:alpine AS builder

# static env variable to enable the use of go modules
ENV GO111MODULE=on

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
ENTRYPOINT ["/main"]
