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

	sudo yum -y install scaleft-server-tools

}

FLAG="/var/log/firstboot.flag"
if [ ! -f $FLAG ];then

	echo "This is the first boot"

	#the next line creates an empty flag file so the script won't run the next boot
	touch $FLAG

    installSftd

fi
