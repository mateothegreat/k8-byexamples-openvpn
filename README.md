<!--
#                                 __                 __
#    __  ______  ____ ___  ____ _/ /____  ____  ____/ /
#   / / / / __ \/ __ `__ \/ __ `/ __/ _ \/ __ \/ __  /
#  / /_/ / /_/ / / / / / / /_/ / /_/  __/ /_/ / /_/ /
#  \__, /\____/_/ /_/ /_/\__,_/\__/\___/\____/\__,_/
# /____                     matthewdavis.io, holla!
#
#-->

[![Clickity click](https://img.shields.io/badge/k8s%20by%20example%20yo-limit%20time-ff69b4.svg?style=flat-square)](https://k8.matthewdavis.io)
[![Twitter Follow](https://img.shields.io/twitter/follow/yomateod.svg?label=Follow&style=flat-square)](https://twitter.com/yomateod) [![Skype Contact](https://img.shields.io/badge/skype%20id-appsoa-blue.svg?style=flat-square)](skype:appsoa?chat)

# OpenVPN @ Kubernetes, Secure LAN access. Keep it buttoned up!

> k8 by example -- straight to the point, simple execution.

## Getting Started

Export your configuration variables (keeps you from having to pass these on each command):

````sh
export NS=infra
export CN=k8.yomateo.io
export REMOTE_TAG=gcr.io/bebuildin/cluster-1/infra-openvpn:latest
```

First we need to generate the certificates used for issuing client certs:
```sh

$ make prepare
docker volume create --name openvpn-data
openvpn-data

$ make pki
docker run --net=none -v openvpn-data:/etc/openvpn --rm -it -e EASYRSA_KEY_SIZE=1024 kylemanna/openvpn ovpn_initpki nopass yes

WARNING!!!

You are about to remove the EASYRSA_PKI at: /etc/openvpn/pki
and initialize a fresh PKI here.

...

$ make config
Disable default push of 'block-outside-dns'
Processing PUSH Config: 'dhcp-option DNS 10.15.240.10'
Processing PUSH Config: 'route 10.12.0.0 255.255.0.0'
Processing PUSH Config: 'route 10.15.0.0 255.255.0.0'
Processing PUSH Config: 'dhcp-option DOMAIN cluster.local'
Processing PUSH Config: 'dhcp-option DOMAIN svc.cluster.local'
Processing PUSH Config: 'dhcp-option DOMAIN default.svc.cluster.local'
Successfully generated config
````

Now you can build the openvpn docker image with configs baked into it:

```sh
$ make build push-gcloud
docker build --rm --tag proliant:1.0.0 .

Sending build context to Docker daemon 92.16 kB

Step 1/2 : FROM kylemanna/openvpn:2.4
 ---> 532821c851ac

Step 2/2 : COPY openvpn/server /etc/openvpn
 ---> Using cache
 ---> 137c013cd054

Successfully built 137c013cd054
Successfully tagged proliant:1.0.0

docker tag proliant:1.0.0 gcr.io/streaming-platform-devqa/cluster-2/infra-openvpn:latest
gcloud docker -- push gcr.io/streaming-platform-devqa/cluster-2/infra-openvpn:latest

The push refers to repository [gcr.io/streaming-platform-devqa/cluster-2/infra-openvpn]

679835a0c90c: Layer already exists
b8a94757e349: Layer already exists
2c2c4b7741e1: Layer already exists
74a92dc69120: Layer already exists
0e7ecc5cec9e: Layer already exists
5bef08742407: Layer already exists

latest: digest: sha256:8bface219796f32f0e6507d6a391a7d35a5c4dbd0794dcc213cbe3594f280b81 size: 1571
```

Now we just need to deploy our kubernetes resources using the new docker image!

```sh
$ make deploy

deployment "openvpn" unchanged
service "openvpn" unchanged
```

## Generate certificates

This will run inside a docker container and store your cert data (CA, etc..) using a `docker volume`.

```sh
make issue-myclient-123
```

Your vpn client config will be in the current directory when finished.

## Cleanup

You can delete all resources deployed and data by running

```
make rollback clean
```

## DNS Resolution

It even works on windows :o

```sh
PS C:\Windows\system32> nslookup kubernetes
Server:  kube-dns.kube-system.svc.cluster.local
Address:  10.15.240.10

Non-authoritative answer:
Name:    kubernetes.default.svc.cluster.local
Address:  10.15.240.1

PS C:\Windows\system32> nslookup kubernetes.default
Server:  kube-dns.kube-system.svc.cluster.local
Address:  10.15.240.10

Non-authoritative answer:
Name:    kubernetes.default.svc.cluster.local
Address:  10.15.240.1

PS C:\Windows\system32> nslookup kubernetes.default.svc
Server:  kube-dns.kube-system.svc.cluster.local
Address:  10.15.240.10

Non-authoritative answer:
Name:    kubernetes.default.svc.cluster.local
Address:  10.15.240.1

PS C:\Windows\system32> nslookup kubernetes.default.svc.cluster.local
Server:  kube-dns.kube-system.svc.cluster.local
Address:  10.15.240.10

Non-authoritative answer:
Name:    kubernetes.default.svc.cluster.local
Address:  10.15.240.1

PS C:\Windows\system32> nslookup google.com
Server:  kube-dns.kube-system.svc.cluster.local
Address:  10.15.240.10

Non-authoritative answer:
Name:    google.com
Addresses:  2607:f8b0:4001:c14::8a
          74.125.124.138
          74.125.124.139
          74.125.124.113
          74.125.124.102
          74.125.124.101
          74.125.124.100
```

## See also

* https://github.com/kylemanna/docker-openvpn/blob/master/docs/backup.md
* https://community.openvpn.net/openvpn/wiki/Topology
