NS				?= infra-openvpn
CN				?= vpn.streaming-platform.com
PKI_VOLUME		?= pki-data
DATA_DIR		?= .pki
LS				?= /data/pki
export

init: pki-generate crl-generate crl-configmap-create pki-secret-create

pki-generate: pki-volume-create

	docker run 	--rm -e OVPN_SERVER_URL=tcp://$(CN):1194	\
				-v $(PKI_VOLUME):/etc/openvpn				\
				-ti ptlange/openvpn 						\
				ovpn_initpki

pki-secret-create:

	@$(eval BASE64_CA       :=$(shell base64 -w0 $(DATA_DIR)/pki/ca.crt))
	@$(eval BASE64_DH       :=$(shell base64 -w0 $(DATA_DIR)/pki/dh.pem))
	@$(eval BASE64_TA       :=$(shell base64 -w0 $(DATA_DIR)/pki/ta.key))
	@$(eval BASE64_KEY      :=$(shell base64 -w0 $(DATA_DIR)/pki/private/$(CN).key))
	@$(eval BASE64_ISSUED   :=$(shell base64 -w0 $(DATA_DIR)/pki/issued/$(CN).crt))

	envsubst < manifests/openvpn-pki.yaml  | kubectl --namespace $(NS) apply -f -

#
pki-volume-create: pki-volume-delete

	@docker volume create $(PKI_VOLUME)
	@docker volume inspect $(PKI_VOLUME)

pki-volume-copy:

	@rm -rf $(DATA_DIR)
	@docker run -v $(PKI_VOLUME):/data --name helper busybox true
	@docker cp helper:/data $(DATA_DIR)
	@docker rm helper

pki-volume-ls:

	@docker run --rm -v $(PKI_VOLUME):/data busybox ls -la $(LS)

pki-volume-delete:

	@docker volume rm -f $(PKI_VOLUME)
	@rm -rf $(DATA_DIR)



#
crl-generate:

	docker run 	--rm -e EASYRSA_CRL_DAYS=180 				\
				-v $(PKI_VOLUME):/etc/openvpn 				\
				-ti ptlange/openvpn 						\
				easyrsa gen-crl

crl-configmap-create: crl-configmap-delete

	kubectl create configmap --namespace $(NS) openvpn-crl --from-file=crl.pem=$(DATA_DIR)/pki/crl.pem

crl-configmap-delete:

	@kubectl delete --ignore-not-found --namespace $(NS) cm/openvpn-crl

#

###
#
# install
#
###

install_settings: delete_configmaps delete_pki install_pki install_configmaps

install_configmaps:

	@kubectl delete --ignore-not-found --namespace $(NS) cm/openvpn-template
	@kubectl create --namespace $(NS) configmap openvpn-template --from-file=manifests/openvpn.conf
	@kubectl apply --namespace $(NS) -f manifests/configmaps.yaml

delete_configmaps:

	@kubectl delete --ignore-not-found --namespace $(NS) -f manifests/configmaps.yaml

install_service:

	@kubectl apply --namespace $(NS) -f openvpn-service.yaml

###
#
# deploy
#
###
deploy_openvpn: delete_openvpn

	@kubectl apply --namespace $(NS) -f manifests/deployment.yaml

delete_openvpn:

	@kubectl delete --ignore-not-found --namespace $(NS) -f manifests/deployment.yaml

redeploy_openvpn: delete_openvpn delete_configmaps install_configmaps deploy_openvpn

###
#
# clients
#
###
generate_client:

	docker run --user=$(id -u) -v $(PWD):/etc/openvpn -ti ptlange/openvpn easyrsa build-client-full $(NAME) nopass
	docker run --user=$(id -u) -e OVPN_SERVER_URL=tcp://$(CN):1194 -v $(PWD):/etc/openvpn --rm ptlange/openvpn ovpn_getclient $(NAME) > $(NAME)
