# This file creates a container that runs Database (Percona) with Galera Replication.
#
# Author: Paul Czarkowski
# Date: 08/16/2014

FROM alpine
MAINTAINER Paul Czarkowski "paul@paulcz.net"

ENV ETCD_VERSION=2.2.0 CONFD_VERSION=0.10.0

# Base Deps
RUN \
  apk add ipvsadm --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ && \
  apk add ipvsadm --update-cache bash curl

# download latest stable etcdctl
RUN \
  curl -sSL https://github.com/coreos/etcd/releases/download/v$ETCD_VERSION/etcd-v$ETCD_VERSION-linux-amd64.tar.gz \
    | tar xzf - \
    && cp etcd-v$ETCD_VERSION-linux-amd64/etcd /usr/local/bin/etcd \
    && cp etcd-v$ETCD_VERSION-linux-amd64/etcdctl /usr/local/bin/etcdctl \
    && rm -rf etcd-v$ETCD_VERSION-linux-amd64 \
    && chmod +x /usr/local/bin/etcd \
    && chmod +x /usr/local/bin/etcdctl \
    && mkdir -p /lolbalancer

COPY lolbalancer /lolbalancer/lolbalancer

RUN chmod +x /lolbalancer/lolbalancer

CMD ["/lolbalancer/lolbalancer"]
