#!/bin/bash

# Gateway Setup token
GATEWAY_TOKEN="<replace with your gateway token>"
# Project Enrollment token, to allow for SSH access to the gateway via ASA
ENROLLMENT_TOKEN="<replace with your gateway token>"
# 3rd party APT key/keyring location
# This location is used to store 3rd party apt key/keyrings(s) in alignment with security best practices
# prompting the apt-key add command deprecation

KEYRING_LOC="/usr/local/share/keyrings/"

function addScaleftRepo (){
	echo "Retrieve information about new packages"

	sudo apt-get update -q

	sudo apt-get install -qy curl gpg

	echo "Download scaleFT repo key"

	curl -s https://dist.scaleft.com/pki/scaleft_deb_key.asc -o ./scaleft_deb_key.asc

	echo "Convert key from asc too gpg format"

	gpg --no-default-keyring --keyring ./temp-scaleft-keyring.gpg --import ./scaleft_deb_key.asc
	gpg --no-default-keyring --keyring ./temp-scaleft-keyring.gpg --export --output ./scaleft_deb_key.gpg
	rm ./temp-scaleft-keyring.gpg
	rm ./scaleft_deb_key.asc

	echo "Move key to third party keyring store"
	
	sudo mkdir -p "$KEYRING_LOC"

	sudo mv ./scaleft_deb_key.gpg "$KEYRING_LOC"

	echo "Add the ScaleFT apt repo to your /etc/apt/sources.list.d/scaleft.list"

	echo "deb [signed-by=${KEYRING_LOC}scaleft_deb_key.gpg] http://pkg.scaleft.com/deb/ linux main" | sudo tee -a /etc/apt/sources.list.d/scaleft.list

	echo "Retrieve information about new packages"

	sudo apt-get update -q
}

function installSft_gateway() {

	echo "Add an enrollment token"

	sudo mkdir -p /var/lib/sft-gatewayd

	echo "$GATEWAY_TOKEN" | sudo tee /var/lib/sft-gatewayd/setup.token

	export DEBIAN_FRONTEND=noninteractive

	echo "Add a basic sftd configuration"

	sudo mkdir -p /etc/sft/

	sftgwcfg=$(cat <<-EOF

	# The setup token from Advanced Server Access. This is required for the gateway to start correctly.

	# SetupToken: yoursetuptoken

	

	# The network address clients will be instructed to use to access this gateway.

	# AccessAddress: "1.1.1.1"

	# The network port clients will be instructed to use to access this gateway.

	# AccessPort: 7234

	

	# The network address that the gateway will listen on.

	# ListenAddress: "0.0.0.0"

	# The network port that the gateway will listen on.

	# ListenPort: 7234

	

	# The URL to an HTTP CONNECT proxy used for outbound network connectivity to

	# Advanced Server Access. Alternatively, use the HTTPS_PROXY environment

	# variable to configure this proxy. Default: none

	# ForwardProxy: https://proxy.mycompany.example

	

	# Forces the gateway to use the bundled certificate store (instead of the OS certificate store)

	# to secure HTTP requests with TLS. This also includes requests to the

	# Advanced Server Access cloud service.

	# To use the OS certificate store, set to false. Default: true

	# TLSUseBundledCAs: true

	

	# Verbosity of the logs. info is the default and recommended.

	# Possible values: debug, info, warn, error

	# LogLevel: info

	

	# The directory where finalized session logs are stored.

	# SessionLogDir: "/var/log/sft/sessions"

	

	# Controls how frequently to sign and flush logs for an active session

	# Logs are flushed after exceeding either value. Valid time units for

	# the flush interval are "ns", "us" (or "µs"), "ms", “s”, ”m”, "h".

	# The max buffer size is in bytes.

	# SessionLogFlushInterval: 10s

	# SessionLogMaxBufferSize: 262144

	EOF

	)

	echo -e "$sftgwcfg" | sudo tee /etc/sft/sft-gatewayd.yaml



	echo "Install sft-gateway"

	sudo apt-get install -qy scaleft-gateway

	
}

function installSftd() {

	echo "Add an enrollment token"

	sudo mkdir -p /var/lib/sftd

	echo "$ENROLLMENT_TOKEN" | sudo tee /var/lib/sftd/enrollment.token

	export DEBIAN_FRONTEND=noninteractive

	echo "Add a basic sftd configuration"

	sudo mkdir -p /etc/sft/

	sftcfg=$(cat <<-EOF

	---

	# CanonicalName: Specifies the name clients should use/see when connecting to this host.

	CanonicalName: "$HOSTNAME"

	EOF

	)

	echo -e "$sftcfg" | sudo tee /etc/sft/sftd.yaml

	echo "Install sftd"

	sudo apt-get install -qy scaleft-server-tools

}

function installSftClientTools() {
	sudo apt-get install -qy scaleft-client-tools 
}

function addSsh-RsaSigning() {
	echo "Add ssh-rsa key signing to sshd_config, required for OpenSSH 8.2+ compatibility"

	echo "CASignatureAlgorithms ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa" | sudo tee -a /etc/ssh/sshd_config

	sudo systemctl restart sshd

}

FLAG="/var/log/firstboot.flag"
if [ ! -f $FLAG ];then

	echo "This is the first boot"

	#the next line creates an empty flag file so the script won't run the next boot
	touch $FLAG

    addScaleftRepo
	installSft_gateway
	installSftd
	addSsh-RsaSigning

fi

