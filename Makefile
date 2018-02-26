#                                 __                 __
#    __  ______  ____ ___  ____ _/ /____  ____  ____/ /
#   / / / / __ \/ __ `__ \/ __ `/ __/ _ \/ __ \/ __  /
#  / /_/ / /_/ / / / / / / /_/ / /_/  __/ /_/ / /_/ /
#  \__, /\____/_/ /_/ /_/\__,_/\__/\___/\____/\__,_/
# /____                     matthewdavis.io, holla!
#
include .make/Makefile.inc
# include $(MAKE_INCLUDE)/Makefile.inc

IMAGE_NAME    	?= docker-alpine-openvpn
VERSION	    	?= 1.0.0
NS				?= default
CN				?= 
DATA_VOLUME		?= $(CN)-openvpn-data
# REMOTE_TAG  	?= gcr.io/streaming-platform-devqa/cluster-4/infra-openvpn:latest
REMOTE_TAG  	?= docker.io/appsoa/docker-alpine-k8-devenv:latest
APP				?= openvpn
DNS				?= 
export

## Performs all setup tasks (make prepare pki config copy build). Push the docker image to your repo & next just make issue-cert NAME=cert
deploy: setup install

setup:  prepare config pki copy build push

## Delete docker volume and kubernetes deployment & service
clean: delete

	-docker rm -f -v openvpn
	-docker volume rm $(DATA_VOLUME)

## Prepare the docker volume for storing vpn config and cert data
prepare:

	docker volume create --name $(DATA_VOLUME)

## Generate openvpn configurations
config: guard-PODS_SUBNET guard-SERVICES_SUBNET guard-DNS prepare
# -u for the VPN server address and port
# -n for all the DNS servers to use
# -s to define the VPN subnet (as it defaults to 10.2.0.0 which is used by Kubernetes already)
# -d to disable NAT
# -p to push options to the client
# -N to enable NAT: it seems critical for this setup on Kubernetes
# -p "route $(PODS_SUBNET)" \

	@docker run --net=none -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn rm -rf /etc/openvpn/openvpn.conf /etc/openvpn/ovpn_env.sh

	@docker run --net=none 	-v $(DATA_VOLUME):/etc/openvpn --rm \
				kylemanna/openvpn ovpn_genconfig -d	-N -u tcp://$(CN) 	\
													-n $(DNS) \
													-p "route $(PODS_SUBNET)" \
													-p "route $(SERVICES_SUBNET)" \
													-p "dhcp-option DOMAIN cluster.local" \
													-p "dhcp-option DOMAIN svc.cluster.local" \
													-p "dhcp-option DOMAIN default.svc.cluster.local"

	echo "topology subnet" | docker run -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn tee -a /etc/openvpn/openvpn.conf

	docker run --net=none -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn cat /etc/openvpn/openvpn.conf

## Generate certificates
pki: config

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm -i -e EASYRSA_KEY_SIZE=1024 kylemanna/openvpn ovpn_initpki nopass yes

## Copy all configuration and certificate data from docker volume to ./openvpn
copy:

	# Start container so we can line up all of the data
	rm -rf openvpn
	-docker rm -f openvpn


	docker run --net=none --rm -v $(DATA_VOLUME):/etc/openvpn kylemanna/openvpn ovpn_copy_server_files
	docker run -v $(DATA_VOLUME):/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name openvpn kylemanna/openvpn

	docker cp openvpn:/etc/openvpn openvpn

## Build docker image with config & cert data
build:

	docker build --rm --tag $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(REMOTE_TAG)

## Push docker image to docker hub
push:

	docker push $(REMOTE_TAG)

## Dumps docker volume (certs and data) to a tarball locally
backup:

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm kylemanna/openvpn tar -cvf - -C /etc openvpn | xz > openvpn-backup.tar.xz

## Uses local tarball to populate docker volume
restore:

	docker volume create --name $(DATA_VOLUME)
	xzcat openvpn-backup.tar.xz | docker run -v $OVPN_DATA:/etc/openvpn -i kylemanna/openvpn tar -xvf - -C /etc


## Generate client certificate (make issue-client NAME="my-client-name")
issue-cert:

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm -i kylemanna/openvpn easyrsa build-client-full $(NAME) nopass
	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $(NAME) > $(NAME).ovpn

## Overwrites /etc/resolv.conf with cluster settings
resolv-conf: guard-DNS

	sudo echo "search cluster.local svc.cluster.local default.svc.cluster.local" > /etc/resolv.conf
	sudo echo "nameserver $(DNS)" >> /etc/resolv.conf
	sudo echo "nameserver 8.8.8.8" >> /etc/resolv.conf
	sudo echo "nameserver 8.8.4.4" >> /etc/resolv.conf

	nslookup kubernetes