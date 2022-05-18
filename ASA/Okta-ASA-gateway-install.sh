#!/bin/bash

# Gateway Setup token
GATEWAY_TOKEN="<replace with your gateway token>"
# Project Enrollment token, to allow for SSH access to the gateway via ASA
ENROLLMENT_TOKEN="<replace with your gateway project enrollement token>"
# 3rd party APT key/keyring location
# This location is used to store 3rd party apt key/keyrings(s) in alignment with security best practices
# prompting the apt-key add command deprecation

KEYRING_LOC="/usr/share/keyrings/"

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

	echo "deb [signed-by=${KEYRING_LOC}scaleft_deb_key.gpg] http://pkg.scaleft.com/deb/ focal main" | sudo tee -a /etc/apt/sources.list.d/scaleft.list

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

	RDP:
        Enabled: true
        DangerouslyIgnoreServerCertificates: true

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

FLAG="/var/log/firstboot.flag"
if [ ! -f $FLAG ];then

	echo "This is the first boot"

	#the next line creates an empty flag file so the script won't run the next boot
	touch $FLAG

    addScaleftRepo
	installSft_gateway
	installSftd
    installSftClientTools
	
fi

