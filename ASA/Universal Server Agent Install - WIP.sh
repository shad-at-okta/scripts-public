#!/bin/bash -x

# To install the ASA server agent, uncomment the following line:
INSTALL_SERVER_TOOLS=true

# Except when using an AWS or GCP account/project linked with an ASA project, 
# an enrollment token for the server agent is required.
# If using an enrollment token, uncomment the ENROLLMENT_TOKEN line below and replace 
# the text between quotes with your project enrollment token
#SERVER_ENROLLMENT_TOKEN="<replace with your project enrollement token>"

# To leverage ASA for machine to machine authentication, the ASA client tools are required.
# To install the ASA client tools, uncomment the following line:
#INSTALL_CLIENT_TOOLS=true
# ASA Client tools will automatically be installed with the ASA Gateway service
# for use in decoding SSH and RDP session recordings.

# To install the ASA Gateway service, uncomment the following line:
#INSTALL_GATEWAY=true
# When installing ASA Gateway service, uncomment the following line and replace 
# the text between quotes with your gateway setup token
#GATEWAY_TOKEN="<replace with your gateway setup token>"


function getVersionInteger(){
# Check if the cut command is available
	if which cut >/dev/null 2>&1; then
		# Cut is available, use it to extract the integer part
		VERSION=$(echo $VERSION | cut -d. -f1)
	else
	# Cut is not available, check if awk is available
		if which awk >/dev/null 2>&1; then
			# Awk is available, use it to extract the integer part
			VERSION=$(echo $VERSION | awk -F. '{print $1}')
		else
			# Awk is not available, use sed to extract the integer part
			VERSION=$(echo $VERSION | sed 's/\..*//')
		fi
	fi

}

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

	# Adjust variables to align with package distrubtion structure where necessary
	case "$DISTRIBUTION" in
		amzn)
			DISTRIBUTION="amazonlinux"
			;;
		rhel|sles)
			getVersionInteger
			;;
		freebsd)
			getVersionInteger
			if [[ "$CPU_ARCH" == "x86_64" ]];then
				CPU_ARCH="amd64"
			fi
			;;
	esac
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
	else
		# Since this instance is not hosted in AWS, assume hostname is friendly.
		INSTANCE_NAME=$HOSTNAME
		echo "This host is not hosted in AWS"
	fi
	echo "Setting server name used in ASA to $INSTANCE_NAME."
}

function updatePackageManager(){
	# Add Okta ASA/OPA repository to local package manager
	case "$DISTRIBUTION" in
		amazonlinux|rhel|centos|alma|fedora)
			if which dnf >/dev/null 2>&1;then
				PACKAGE_MANAGER="dnf"
			else
				PACKAGE_MANAGER="yum"
			fi
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
			
			sudo $PACKAGE_MANAGER update -qy
			
			;;
		ubuntu|debian)
			PACKAGE_MANAGER="apt-get"
			echo "Adding Okta repository to local package manager for Ubuntu or Debian"
			sudo $PACKAGE_MANAGER update -qy
			sudo $PACKAGE_MANAGER install -qy curl gpg
			curl -fsSL https://dist.scaleft.com/GPG-KEY-OktaPAM-2023 | gpg --dearmor | sudo tee /usr/share/keyrings/oktapam-2023-archive-keyring.gpg > /dev/null
			echo "deb [signed-by=/usr/share/keyrings/oktapam-2023-archive-keyring.gpg] https://dist.scaleft.com/repos/deb $CODENAME okta" | sudo tee /etc/apt/sources.list.d/scaleft.list
			sudo $PACKAGE_MANAGER update -qy
			;;
		
		freebsd)
			#There is currenlty no pkg repo integration, so downloading the packages locally for installation

			PKG_BASE_URL="https://dist.scaleft.com/repos/$DISTRIBUTION/stable/$VERSION/$CPU_ARCH/"

			# Use cURL to get the directory listing from the URL
			RESPONSE=$(curl -s $PKG_BASE_URL)

			# Use grep to extract the directories from the RESPONSE
			PKG_VERSIONS=$(echo "$RESPONSE" | grep -o ">[0-9.]*<" | tr -d '<>' | sort -V)

			# Get the highest version directory from the list
			HIGH_VERSION=$(echo "$PKG_VERSIONS" | tail -n1)

			curl -O "$PKG_BASE_URL/$HIGH_VERSION/scaleft-server-tools-$HIGH_VERSION.pkg"
			curl -O "$PKG_BASE_URL/$HIGH_VERSION/scaleft-client-tools-$HIGH_VERSION.pkg"
			curl -O "$PKG_BASE_URL/$HIGH_VERSION/scaleft-gateway-$HIGH_VERSION.pkg"
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

function createSftGatewaySetupToken(){
	if [ -z "$GATEWAY_TOKEN" ]; then
		echo "Unable to create sft-gatewayd setup token. GATEWAY_TOKEN is not set or is empty"
	else
		echo "Add an enrollment token"

		sudo mkdir -p /var/lib/sft-gatewayd

		echo "$GATEWAY_TOKEN" | sudo tee /var/lib/sft-gatewayd/setup.token
	fi
}

function createSftGwConfigRDP(){
	sudo mkdir -p /var/lib/sft-gatewayd
	sftgwcfg=$(cat <<-EOF
	#Loglevel: debug

	LDAP:
	  StartTLS: false

	RDP:
	  Enabled: true
	  DangerouslyIgnoreServerCertificates: true

	LogFileNameFormats:
  	  SSHRecording: "{{.Protocol}}~{{.StartTime}}~{{.TeamName}}~{{.ProjectName}}~{{.ServerName}}~{{.Username}}~"
  	  RDPRecording: "{{.Protocol}}~{{.StartTime}}~{{.TeamName}}~{{.ProjectName}}~{{.ServerName}}~{{.Username}}~"

	EOF
	
	)
	echo -e "$sftgwcfg" | sudo tee /etc/sft/sft-gatewayd.yaml
}

function createSftGwConfig(){
	sudo mkdir -p /var/lib/sft-gatewayd
	sftgwcfg=$(cat <<-EOF
	#Loglevel: debug
	
	LogFileNameFormats:
		SSHRecording: "{{.Protocol}}~{{.StartTime}}~{{.TeamName}}~{{.ProjectName}}~{{.ServerName}}~{{.Username}}~"
	
	EOF

	)
	echo -e "$sftgwcfg" | sudo tee /etc/sft/sft-gatewayd.yaml
}

function installSftd(){
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-server-tools-$HIGH_VERSION.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-server-tools -qy
	fi
}

function installSft(){
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-client-tools-$HIGH_VERSION.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-client-tools -qy
	fi
}

function installSft-Gateway(){
	if [[ "$DISTRIBUTION" == "rhel" && "$VERSION" == "8" ]] || [[ "$DISTRIBUTION" == "ubuntu" && ( "$VERSION" == "20.04" || "$VERSION" == "22.04" ) ]]; then
		sudo $PACKAGE_MANAGER install scaleft-rdp-transcoder
		createSftGwConfigRDP
	else
		createSftdConfig
	fi
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-gateway-$HIGH_VERSION.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-gateway
	fi
}

#main script body below

getOsData
updatePackageManager

if [[ "$INSTALL_SERVER_TOOLS" == "true" ]];then
	getServerName
	createSftdConfig
	createSftdEnrollmentToken
	installSftd
fi

if [[ "$INSTALL_GATEWAY" == "true" ]];then
	createSftGatewaySetupToken
	installSft-Gateway
	INSTALL_CLIENT_TOOLS="true"
fi

if [[ "$INSTALL_CLIENT_TOOLS" == "true" ]];then
	installSft
fi

