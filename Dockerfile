# git-all-secrets build container
FROM golang:1.10.3-alpine3.7 AS build-env
RUN apk update

RUN apk add --no-cache --upgrade git openssh-client ca-certificates
RUN go get -u github.com/golang/dep/cmd/dep

WORKDIR /go/src/github.com/anshumanbh/git-all-secrets
COPY Gopkg.toml Gopkg.lock ./
RUN dep ensure -vendor-only -v
COPY main.go ./
RUN go build -v -o /go/bin/git-all-secrets

# Final container
FROM node:9.11.2-alpine

COPY --from=build-env /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build-env /go/bin/git-all-secrets /usr/bin/git-all-secrets
RUN apk update

RUN apk add --no-cache --upgrade git openssh-client ca-certificates
RUN apk add --no-cache --upgrade git python py-pip jq

# Create a generic SSH config for Github
WORKDIR /root/.ssh
RUN echo "Host *github.com \
\n  IdentitiesOnly yes \
\n  StrictHostKeyChecking no \
\n  UserKnownHostsFile=/dev/null \
\n  IdentityFile /root/.ssh/id_rsa \
\n  \
\n Host github.*.com \
\n  IdentitiesOnly yes \
\n  StrictHostKeyChecking no \
\n  UserKnownHostsFile=/dev/null \
\n  IdentityFile /root/.ssh/id_rsa" > /root/.ssh/config
RUN echo "StrictHostKeyChecking no" >> /root/.ssh/config
RUN git clone https://github.com/anshumanbh/repo-supervisor.git /root/repo-supervisor &&\
    git clone https://github.com/dxa4481/truffleHog.git /root/truffleHog

# Install truffleHog
RUN pip install trufflehog
COPY rules.json /root/truffleHog/

# Install repo-supervisor
WORKDIR /root/repo-supervisor
COPY runreposupervisor.sh ./
RUN chmod +x runreposupervisor.sh
RUN npm install --no-optional && \
    npm run build && \
    npm run cli ./src/

WORKDIR /root/
ENTRYPOINT [ "git-all-secrets"]
