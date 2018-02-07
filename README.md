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

First we need to generate the certificates used for issuing client certs:

```sh
 make delete build push-gcloud delete-deployment install-deployment REMOTE_TAG=gcr.io/streaming-platform-devqa/cluster-2/infra-openvpn:latest
```

This will run inside a docker container and store your cert data (CA, etc..) using a `docker volume`.

Now you can generate certificates anytime by simply running:

```sh
make issue NAME=myclient
```

Your vpn client config will be in the current directory when finished.

## Cleanup

You can delete all resources deployed and data by running

```
make delete
```

## See also

* https://github.com/kylemanna/docker-openvpn/blob/master/docs/backup.md
