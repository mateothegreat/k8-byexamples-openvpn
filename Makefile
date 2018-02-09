#                                 __                 __
#    __  ______  ____ ___  ____ _/ /____  ____  ____/ /
#   / / / / __ \/ __ `__ \/ __ `/ __/ _ \/ __ \/ __  /
#  / /_/ / /_/ / / / / / / /_/ / /_/  __/ /_/ / /_/ /
#  \__, /\____/_/ /_/ /_/\__,_/\__/\___/\____/\__,_/
# /____                     matthewdavis.io, holla!
#
include .make/Makefile.inc

NAME	    ?= docker-alpine-openvpn
VERSION	    ?= 1.0.0
NS			?= infra-openvpn
CN			?= vpn.streaming-platform.com
DATA_VOLUME	?= openvpn-data
export

setup:  prepare pki config copy build push-gcloud

prepare:

	docker volume create --name $(DATA_VOLUME)

config: prepare
# -u for the VPN server address and port
# -n for all the DNS servers to use
# -s to define the VPN subnet (as it defaults to 10.2.0.0 which is used by Kubernetes already)
# -d to disable NAT
# -p to push options to the client
# -N to enable NAT: it seems critical for this setup on Kubernetes

	@docker run --net=none -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn rm -rf /etc/openvpn/openvpn.conf /etc/openvpn/ovpn_env.sh

	@docker run --net=none 	-v $(DATA_VOLUME):/etc/openvpn --rm \
				kylemanna/openvpn ovpn_genconfig -d	-N -u tcp://$(CN) 	\
													-n 10.11.240.10 \
													-p "route 10.8.0.0 255.255.0.0" \
													-p "route 10.11.0.0 255.255.0.0" \
													-p "dhcp-option DOMAIN cluster.local" \
													-p "dhcp-option DOMAIN svc.cluster.local" \
													-p "dhcp-option DOMAIN default.svc.cluster.local"

	echo "topology subnet" | docker run -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn tee -a /etc/openvpn/openvpn.conf

	docker run --net=none -v openvpn-data:/etc/openvpn -i --rm kylemanna/openvpn cat /etc/openvpn/openvpn.conf

pki: prepare

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm -it -e EASYRSA_KEY_SIZE=1024 kylemanna/openvpn ovpn_initpki nopass yes

copy:

	# Start container so we can line up all of the data
	rm -rf openvpn
	-docker kill openvpn


	docker run --net=none --rm -d -v $(DATA_VOLUME):/etc/openvpn kylemanna/openvpn ovpn_copy_server_files
	docker run -v $(DATA_VOLUME):/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name openvpn kylemanna/openvpn

	docker cp openvpn:/etc/openvpn openvpn

build:

	docker build --rm --tag $(NAME):$(VERSION) .
	docker tag $(NAME):$(VERSION) $(REMOTE_TAG)

clean:

	-docker rm -f -v openvpn

push-gcloud:

	gcloud docker -- push $(REMOTE_TAG)

backup:

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm kylemanna/openvpn tar -cvf - -C /etc openvpn | xz > openvpn-backup.tar.xz

restore:

	docker volume create --name $(DATA_VOLUME)
	xzcat openvpn-backup.tar.xz | docker run -v $OVPN_DATA:/etc/openvpn -i kylemanna/openvpn tar -xvf - -C /etc

delete: delete-deployment delete-service

	docker volume rm $(DATA_VOLUME)
	rm -rf openvpn

## Generate client certificate (make client NAME="my-client-name")
issue-%:

	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $* nopass
	docker run --net=none -v $(DATA_VOLUME):/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $* > $*.ovpn
