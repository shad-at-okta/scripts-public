#!/bin/bash
# Scripts provided as examples only, with no warranty expressed or implied, and with no ongoing technical support provided by Okta, Inc.

# Project enrollment token
ENROLLMENT_TOKEN="<replace with your enrollment token>"

function installSftd() {

	echo "Add an enrollment token"

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

	echo "Download scaleFT repo key"

	sudo rpm --import https://dist.scaleft.com/pki/scaleft_rpm_key.asc

	echo "Add the ScaleFT repo "

	curl -C - https://pkg.scaleft.com/scaleft_yum.repo | sudo tee /etc/yum.repos.d/scaleft.repo

	echo "Install sftd"

	sudo yum install scaleft-server-tools

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
