NS				?= infra-openvpn
CN				?= vpn.streaming-platform.com
PKI_VOLUME		?= pki-data
DATA_DIR		?= .pki
LS				?= /data/pki
export

all: 	help
## Perform all certficate tasks before being able to issue client certs
init:   pki-generate crl-generate pki-volume-copy pki-secret-create
## Delete all data & resources (In order to delete the data volume for cert issuing you must run `make pki-volume-delete` manually)
delete:  configmaps-delete deployment-delete pki-delete-container

## Install Deployment & ConfigMap Resources (make HOSTNAME=myvpn.domain.com deploy)
deploy:     configmaps-install deployment-install service-install
## Delete & Install Deployment & ConfigMap Resources (make HOSTNAME=myvpn.domain.com deploy)
redeploy:   deployment-delete configmaps-delete service-delete deploy


## Generate client certificate (make client NAME="my-client-name")
client:

	docker run --user=$(id -u) 	-v $(PKI_VOLUME):/etc/openvpn -
								ti ptlange/openvpn easyrsa build-client-full $(NAME) nopass

	docker run --user=$(id -u)  -e OVPN_SERVER_URL=tcp://$(CN):1194     \
								-v $(PKI_VOLUME):/etc/openvpn           \
								--rm ptlange/openvpn ovpn_getclient $(NAME) > $(NAME).ovpn


## Create Namespace (default: infra-opevpn)
ns-create:

	@kubectl create ns $(NS)

## Delete Namespace (default: infra-openvpn)
ns-delete:

	@kubectl delete ns $(NS)

## Generate CA
pki-generate: pki-volume-create

	# docker rm -f ovpn_initpki

	docker run 	--rm -e OVPN_SERVER_URL=tcp://$(CN):1194	\
				--name ovpn_initpki                         \
				-v $(PKI_VOLUME):/etc/openvpn				\
				-ti ptlange/openvpn 						\
				ovpn_initpki

## Delete docker container for issuing certs from
pki-delete-container:

	@docker rm -f ovpn_initpki

## Generate PKI certificate data
pki-secret-create:

	@$(eval BASE64_CA       :=$(shell base64 -w0 $(DATA_DIR)/pki/ca.crt))
	@$(eval BASE64_DH       :=$(shell base64 -w0 $(DATA_DIR)/pki/dh.pem))
	@$(eval BASE64_TA       :=$(shell base64 -w0 $(DATA_DIR)/pki/ta.key))
	@$(eval BASE64_KEY      :=$(shell base64 -w0 $(DATA_DIR)/pki/private/$(CN).key))
	@$(eval BASE64_ISSUED   :=$(shell base64 -w0 $(DATA_DIR)/pki/issued/$(CN).crt))

	envsubst < manifests/openvpn-pki.yaml  | kubectl --namespace $(NS) apply -f -

## Create local Docker Volume for PKI data
pki-volume-create: pki-volume-delete

	@docker volume create $(PKI_VOLUME)
	@docker volume inspect $(PKI_VOLUME)

## Copy PKI data from volume to local filesystem
pki-volume-copy:

	@rm -rf $(DATA_DIR)
	@docker run -v $(PKI_VOLUME):/data --name helper busybox true
	@docker cp helper:/data $(DATA_DIR)
	@docker rm helper

## List contents of PKI data volume
pki-volume-ls:

	@docker run --rm -v $(PKI_VOLUME):/data busybox ls -la $(LS)

## Delete PKI data volume (you will lose ability to issue certs!)
pki-volume-delete:

	@docker volume rm -f $(PKI_VOLUME)
	@rm -rf $(DATA_DIR)

## Generate CRL
crl-generate:

	docker run 	--rm -e EASYRSA_CRL_DAYS=180 				\
				-v $(PKI_VOLUME):/etc/openvpn 				\
				-ti ptlange/openvpn 						\
				easyrsa gen-crl

## Install ConfigMaps
configmaps-install:

	@kubectl delete --ignore-not-found --namespace $(NS) cm/openvpn-crl
	@kubectl create configmap --namespace $(NS) openvpn-crl --from-file=crl.pem=$(DATA_DIR)/pki/crl.pem

	@kubectl delete --ignore-not-found --namespace $(NS) cm/openvpn-template
	@kubectl create --namespace $(NS) configmap openvpn-template --from-file=manifests/openvpn.tmpl
	@kubectl apply --namespace $(NS) -f manifests/configmaps.yaml

## Delete ConfigMaps
configmaps-delete:

	@kubectl delete --ignore-not-found --namespace $(NS) -f manifests/configmaps.yaml

## Install Deployment Resource
deployment-install:

	@kubectl apply --namespace $(NS) -f manifests/deployment.yaml

## Delete Deployment Resource
deployment-delete:

	@kubectl delete --ignore-not-found --namespace $(NS) -f manifests/deployment.yaml

## Install Service Resource (this will become the vpn endpoint, use $HOSTNAME: make service-install HOSTNAME=myvpn.domain.com)
service-install:

	@envsubst < manifests/service.yaml | kubectl apply --namespace $(NS) -f -

## Delete Deployment Resource
service-delete:

	@envsubst < manifests/service.yaml | kubectl delete --ignore-not-found --namespace $(NS) -f -

## Follow log output from openvpn pod
logs:

	kubectl logs -n $(NS) -f $(shell kubectl get pods -n $(NS) -l openvpn=$(CN) -o jsonpath='{.items[0].metadata.name}')

# Help Outputs
GREEN  		:= $(shell tput -Txterm setaf 2)
YELLOW 		:= $(shell tput -Txterm setaf 3)
WHITE  		:= $(shell tput -Txterm setaf 7)
RESET  		:= $(shell tput -Txterm sgr0)
help:

	@echo "Deploy & Manage OpenVPN in Kubernetes."
	@echo "\nUsage:\n\n  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}\n\nTargets:\n"
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-20s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
