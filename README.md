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
make init
```

This will run inside a docker container and store your cert data (CA, etc..) using a `docker volume`. \*Your data will be copied to the filesystem after generation. You can also run `make pki-volume-ls` or `make pki-volume-copy ..` to see your data.

Now we just need to deploy everything:

```sh
make deploy
```

Now you can generate certificates anytime by simply running:

```sh
make client NAME=myclient
```

Your vpn client config will be in the current directory when finished.

## Usage

```sh
Deploy & Manage OpenVPN in Kubernetes.

Usage:

  make <target>

Targets:

  init                 Perform all certficate tasks before being able to issue client certs
  delete               Delete all data & resources (In order to delete the data volume for cert issuing you must run `make pki-volume-delete` manually)
  deploy               Install Deployment & ConfigMap Resources (make HOSTNAME=myvpn.domain.com deploy)
  redeploy             Delete & Install Deployment & ConfigMap Resources (make HOSTNAME=myvpn.domain.com deploy)
  client               Generate client certificate (make client NAME="my-client-name")
  ns-create            Create Namespace (default: infra-opevpn)
  ns-delete            Delete Namespace (default: infra-openvpn)
  pki-generate         Generate CA
  pki-delete-container Delete docker container for issuing certs from
  pki-secret-create    Generate PKI certificate data
  pki-volume-create    Create local Docker Volume for PKI data
  pki-volume-copy      Copy PKI data from volume to local filesystem
  pki-volume-ls        List contents of PKI data volume
  pki-volume-delete    Delete PKI data volume (you will lose ability to issue certs!)
  crl-generate         Generate CRL
  configmaps-install   Install ConfigMaps
  configmaps-delete    Delete ConfigMaps
  deployment-install   Install Deployment Resource
  deployment-delete    Delete Deployment Resource
  service-install      Install Service Resource (this will become the vpn endpoint, use $HOSTNAME: make service-install HOSTNAME=myvpn.domain.com)
  service-delete       Delete Deployment Resource
  logs                 Follow log output from openvpn pod
```

## Cleanup

You can delete all resources deployed and data by running

```
make delete pki-volume-delete
```
