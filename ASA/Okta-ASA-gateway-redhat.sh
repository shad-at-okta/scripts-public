#!/bin/bash
# Scripts provided as examples only, with no warranty expressed or implied, and with no ongoing technical support provided by Okta, Inc.

# Gateway Setup token
GATEWAY_TOKEN="<replace with your gateway token>"
# Project Enrollment token, to allow for SSH access to the gateway via ASA
ENROLLMENT_TOKEN="<replace with your gateway project enrollement token>"

function addScaleftRepo () {
	echo "Ensure curl is installed"

	sudo yum -y install curl

	echo "Download scaleFT repo key"

	sudo rpm --import https://dist.scaleft.com/pki/scaleft_rpm_key.asc

	echo "Add the ScaleFT repo"

	curl -C - https://pkg.scaleft.com/scaleft_yum.repo | sudo tee /etc/yum.repos.d/scaleft.repo

	echo "Rebuild yum cache"
	sudo yum makecache
}

function installSft_gateway() {

	echo "Create gateway enrollment token file"

	sudo mkdir -p /var/lib/sft-gatewayd

	echo "$GATEWAY_TOKEN" | sudo tee /var/lib/sft-gatewayd/setup.token

	echo "Install sft-gateway"

	sudo yum -y install scaleft-gateway
	
}

function installSftd() {

	echo "Create server agent enrollment token file"

	sudo mkdir -p /var/lib/sftd

	echo "$ENROLLMENT_TOKEN" | sudo tee /var/lib/sftd/enrollment.token

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

	sudo yum -y install scaleft-server-tools

}

function installSftClientTools() {
	sudo yum -y install scaleft-client-tools 
}

FLAG="/var/log/firstboot.flag"
if [ ! -f $FLAG ];then

	echo "This is the first boot"

	#the next line creates an empty flag file so the script won't run the next boot
	sudo touch $FLAG

    addScaleftRepo
	installSft_gateway
	installSftd
    installSftClientTools

fi
