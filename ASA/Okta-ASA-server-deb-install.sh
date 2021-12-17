#!/bin/bash

# Project enrollment token
ENROLLMENT_TOKEN="<replace with your enrollment token>"

# 3rd party APT key/keyring location
# This location is used to store 3rd party apt key/keyrings(s) in alignment with security best practices
# prompting the apt-key add command deprecation

KEYRING_LOC="/usr/local/share/keyrings/"

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

	echo "Install sftd"

	sudo apt-get install -qy scaleft-server-tools

	echo "Add ssh-rsa key signing to sshd_config, required for OpenSSH 8.2+ compatibility"

	echo "CASignatureAlgorithms ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa" | sudo tee -a /etc/ssh/sshd_config

	sudo systemctl restart sshd

}

FLAG="/var/log/firstboot.flag"
if [ ! -f $FLAG ];then

	echo "This is the first boot"

	#the next line creates an empty flag file so the script won't run the next boot
	touch $FLAG

    installSftd

fi
