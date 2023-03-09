#!/bin/bash

# To install the ASA server agent, uncomment the following line:
INSTALL_SERVER_TOOLS=true

# Except when using an AWS or GCP account/project linked with an ASA project, 
# an enrollment token for the server agent is required.
# If using an enrollment token, uncomment the ENROLLMENT_TOKEN line below and replace 
# the text between quotes with your project enrollment token
#SERVER_ENROLLMENT_TOKEN="<replace with your gateway project enrollement token>"

# To leverage ASA for machine to machine authentication, the ASA client tools are required.
# To install the ASA client tools, uncomment the following line:
#INSTALL_CLIENT_TOOLS=true
# ASA Client tools will automatically be installed with the ASA Gateway service
# for use in decoding SSH and RDP session recordings.

# To install the ASA Gateway service, uncomment the following line:
#INSTALL_GATEWAY=true
# When installing ASA Gateway service, uncomment the following line and replace 
# the text between quotes with your gateway setup token
#GATEWAY_TOKEN="<replace with your gateway token>"



function getOsData(){
	# Get distribution, version, and code name
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		DISTRIBUTION=$ID
		VERSION=$VERSION_ID
		CODENAME=$VERSION_CODENAME
	elif [ -f /etc/lsb-release ]; then
		. /etc/lsb-release
		DISTRIBUTION=${DISTRIB_ID,,}
		VERSION=$DISTRIB_RELEASE
		CODENAME=$DISTRIB_CODENAME
	else
		DISTRIBUTION=$(uname -s)
		VERSION=$(uname -r)
		CODENAME=""
	fi

	# Get CPU Architecture
	CPU_ARCH=$(uname -m)

	if [["$DISTRIBUTION" == "amzn"]]; then
		DISTRIBUTION="amazonlinux"
	fi
}

function getServerName(){
	# Determine the server name that will appear in ASA
	if curl -s http://169.254.169.254/latest/dynamic/instance-identity/document >/dev/null 2>&1; then
		echo "This instance is hosted in AWS, attempting to retrieve Name tag."
		# Retrieve the instance name tag
		if curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name >/dev/null 2>&1; then
			echo "Using AWS Name tag for server name in ASA."
			INSTANCE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)
		else
			echo "Unable to retrieve Name tag, using hostname for server name in ASA."
			INSTANCE_NAME=$HOSTNAME	
		fi
		echo "Instance not hosted in AWS, using hostname for server name in ASA."
		echo "Instance Name: $INSTANCE_NAME"
	else
		INSTANCE_NAME=$HOSTNAME
		echo "This host is not hosted in AWS"
	fi
	echo "Setting server name used in ASA to $INSTANCE_NAME."
}

function updatePackageManager(){
	# Add Okta ASA/OPA repository to local package manager
	case "$DISTRIBUTION" in
	amazonlinux|rhel|centos|alma|fedora)
		echo "Adding Okta repository to local package manager for Amazon Linux, RHEL, CentOS, Alma, or Fedora"
		sudo rpm --import https://dist.scaleft.com/GPG-KEY-OktaPAM-2023
		rpm_art=$(cat <<-EOF
		[oktapam-stable]
		name=Okta PAM Stable - $DISTRIBUTION $VERSION
		baseurl=https://dist.scaleft.com/repos/rpm/stable/$DISTRIBUTION/$VERSION/$CPU_ARCH
		gpgcheck=1
		repo_gpgcheck=1
		enabled=1
		gpgkey=https://dist.scaleft.com/GPG-KEY-OktaPAM-2023
		EOF
		)
		
		echo -e "$rpm_art" | sudo tee /etc/yum.repos.d/oktapam-stable.repo
		
		sudo yum update -qy
		
		;;
	ubuntu|debian)
		echo "Adding Okta repository to local package manager for Ubuntu or Debian"
		sudo apt-get update -qy
		sudo apt-get install -qy curl gpg
		curl -fsSL https://dist.scaleft.com/GPG-KEY-OktaPAM-2023 | gpg --dearmor | sudo tee /usr/share/keyrings/oktapam-2023-archive-keyring.gpg > /dev/null
		echo "deb [signed-by=/usr/share/keyrings/oktapam-2023-archive-keyring.gpg] https://dist.scaleft.com/repos/deb $CODENAME okta" | sudo tee /etc/apt/sources.list.d/scaleft.list
		sudo apt-get update -qy
		;;
	*)
		echo "Unrecognized OS type: $DISTRIBUTION"
		;;
	esac
}

function createSftdConfig() {
	#create sftd configuration file

	echo "Creating basic sftd configuration"
	sudo mkdir -p /etc/sft/

	sftdcfg=$(cat <<-EOF
	 
	---
	 
	# CanonicalName: Specifies the name clients should use/see when connecting to this host.
	 
	CanonicalName: "$INSTANCE_NAME"
	 
	EOF	 
	)

	echo -e "$sftdcfg" | sudo tee /etc/sft/sftd.yaml
}

function createSftdEnrollmentToken(){
	if [ -z "$SERVER_ENROLLMENT_TOKEN" ]; then
		echo "Unable to create sftd enrollment token. SERVER_ENROLLMENT_TOKEN is not set or is empty"
	else
		echo "Creating sftd enrollment token"

		sudo mkdir -p /var/lib/sftd

		echo "$SERVER_ENROLLMENT_TOKEN" | sudo tee /var/lib/sftd/enrollment.token
	fi
}

function createSftGatewayDSetupToken(){
	if [ -z "$GATEWAY_TOKEN" ]; then
		echo "Unable to create sft-gatewayd setup token. GATEWAY_TOKEN is not set or is empty"
	then
		echo "Add an enrollment token"

		sudo mkdir -p /var/lib/sft-gatewayd

		echo "$GATEWAY_TOKEN" | sudo tee /var/lib/sft-gatewayd/setup.token
	fi
}

function installSftd(){

}

function installSft(){

}

function installSft-Gatewayd(){

}