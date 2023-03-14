#!/bin/bash -x

# For headless installation, key variables are initialized below with the appropriate default values.  
# Run with script with -h option for command line options
# This script is provided as-is, with no support or warranty expressed or implied, use at your own risk!

# To install the ASA server agent, set the following value to true:
INSTALL_SERVER_TOOLS=false

# Except when using an AWS or GCP account/project linked with an ASA project, 
# an enrollment token for the server agent is required.
# If using an enrollment token, place the token in between the quotes in the  
# following line:
SERVER_ENROLLMENT_TOKEN=""

# To leverage ASA for machine to machine authentication, the ASA client tools are required.
# To install the ASA client tools, set the following value to true:
INSTALL_CLIENT_TOOLS=false
# ASA Client tools will automatically be installed with the ASA Gateway service
# for use in decoding SSH and RDP session recordings.

# To install the ASA Gateway service, set the following value to true:
INSTALL_GATEWAY=false
# When installing ASA Gateway service, place the gateway setup token between the quotes
# in the following line:
GATEWAY_TOKEN=""

# Some EA and beta features are available only with the latest un-released agents.  These
# agents are currently undergoing rapid development and testing and may be unstable.  Not
# suitable for production deployments!!!
# To switch to the test branch, change the following value to test:
ENVIRONMENT="prod"

# Script functions begin here

function getOptions(){
	while getopts ":S:sg:cb:h" opt; do
	case ${opt} in
		s|S )
		INSTALL_SERVER_TOOLS=true
		if [[ "$OPTARG" =~ ^-.* ]]; then
			# If the next argument is another option, assume no enrollment token was provided
			((OPTIND--))
		else
			SERVER_ENROLLMENT_TOKEN=$OPTARG
		fi
		;;
		g )
		INSTALL_GATEWAY=true
		if [[ "$OPTARG" =~ ^-.* ]]; then
			# If the next argument is another option, assume no gateway token was provided
			((OPTIND--))
		else
			GATEWAY_TOKEN=$OPTARG
		fi
		;;
		c )
		INSTALL_CLIENT_TOOLS=true
		;;
		b )
		if [ "$OPTARG" == "test" ]; then
			ENVIRONMENT="test"
		elif [ "$OPTARG" != "prod" ]; then
			echo "Invalid argument for -b: $OPTARG. Valid options are 'prod' and 'test'" >&2
			exit 1
		fi
		;;
		h )
		echo "Usage: script.sh [-s] [-S server_enrollment_token] [-g GATEWAY_TOKEN] [-c|-b [prod|test]] [-h]"
		echo "	-s                          Install ASA Server Tools without providing an enrollment token."
		echo "	-S server_enrollment_token  Install ASA Server Tools with the provided enrollment token."
		echo "	-g gateway_setup_token      Install ASA Gateway with the provided gateway token."
		echo "	-c                          Install ASA Client Tools."
		echo "	-b                          Set installation branch, default is prod."
		echo "	-h                          Display this help message."
		exit 0
		;;
		\? )
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
		: )
		if [ "$OPTARG" == "s" ]; then
			# The -s option is missing an argument, but it's optional, so just ignore the error
			continue
		else
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
		fi      
		;;
	esac
	done
}

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

	# Make necessary adjustments to align with ASA repo structure
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
			# Set the package manager to dnf if installed, otherwise use yum
			if which dnf >/dev/null 2>&1;then
				PACKAGE_MANAGER="dnf"
			else
				PACKAGE_MANAGER="yum"
			fi
			# Import ASA repo key 
			echo "Adding Okta repository to local package manager for Amazon Linux, RHEL, CentOS, Alma, or Fedora"
			sudo rpm --import https://dist.scaleft.com/GPG-KEY-OktaPAM-2023
			# Create the yum repo artifact for inclusion in the package manager
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
			
			# Update package manager indexes
			sudo $PACKAGE_MANAGER update -qy
			
			;;
		ubuntu|debian)
			# Use apt-get as the package manager
			PACKAGE_MANAGER="apt-get"
			# Update package manager indexes 
			echo "Adding Okta repository to local package manager for Ubuntu or Debian"
			sudo $PACKAGE_MANAGER update -qy
			# Ensure curl and gpg are installed, as they are needed to add ASA repo keys
			sudo $PACKAGE_MANAGER install -qy curl gpg
			# Download and unwrap ASA repo keys
			curl -fsSL https://dist.scaleft.com/GPG-KEY-OktaPAM-2023 | gpg --dearmor | sudo tee /usr/share/keyrings/oktapam-2023-archive-keyring.gpg > /dev/null
			# Create apt-get repo config file
			echo "deb [signed-by=/usr/share/keyrings/oktapam-2023-archive-keyring.gpg] https://dist.scaleft.com/repos/deb $CODENAME okta" | sudo tee /etc/apt/sources.list.d/scaleft.list
			# Update package manager indexes again
			sudo $PACKAGE_MANAGER update -qy
			;;
		
		freebsd)
			# There is currenlty no pkg repo integration, so downloading the packages locally for installation

			pkg_base_url="https://dist.scaleft.com/repos/$DISTRIBUTION/stable/$VERSION/$CPU_ARCH/"

			# Use cURL to get the directory listing from the URL
			response=$(curl -s $pkg_base_url)

			# Use grep to extract the directories from the response
			pkg_versions=$(echo "$response" | grep -o ">[0-9.]*<" | tr -d '<>' | sort -V)

			# Get the highest version directory from the list
			highest_version=$(echo "$pkg_versions" | tail -n1)

			# Download the latest packages
			curl -O "$pkg_base_url/$highest_version/scaleft-server-tools-$highest_version.pkg"
			curl -O "$pkg_base_url/$highest_version/scaleft-client-tools-$highest_version.pkg"
			curl -O "$pkg_base_url/$highest_version/scaleft-gateway-$highest_version.pkg"
			;;
		*)
			echo "Unrecognized OS type: $DISTRIBUTION"
			exit 1
			;;
	esac
}

function createSftdConfig() {
	# Create sftd configuration file

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
	# Create an ASA Server Tools enrollment token file with the provide token value
	if [ -z "$SERVER_ENROLLMENT_TOKEN" ]; then
		echo "Unable to create sftd enrollment token. SERVER_ENROLLMENT_TOKEN is not set or is empty"
	else
		echo "Creating sftd enrollment token"

		sudo mkdir -p /var/lib/sftd

		echo "$SERVER_ENROLLMENT_TOKEN" | sudo tee /var/lib/sftd/enrollment.token
	fi
}

function createSftGatewaySetupToken(){
	# Create an ASA Gateway setup token file with the provided token value
	if [ -z "$GATEWAY_TOKEN" ]; then
		echo "Unable to create sft-gatewayd setup token. GATEWAY_TOKEN is not set or is empty"
		exit 1
	else
		echo "Add an enrollment token"

		sudo mkdir -p /var/lib/sft-gatewayd

		echo "$GATEWAY_TOKEN" | sudo tee /var/lib/sft-gatewayd/setup.token
	fi
}

function createSftGwConfigRDP(){
	# Create an ASA Gateway configuration file for handling SSH & RDP traffic.
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
	# Create an ASA Gateway configuration file for handling only SSH traffic.
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
	# Install ASA Server tools
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-server-tools-$highest_version.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-server-tools -qy
	fi
}

function installSft(){
	# Install ASA Client tools
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-client-tools-$highest_version.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-client-tools -qy
	fi
}

function installSft-Gateway(){
	# Install ASA Gateway
	if [[ "$DISTRIBUTION" == "rhel" && "$VERSION" == "8" ]] || [[ "$DISTRIBUTION" == "ubuntu" && ( "$VERSION" == "20.04" || "$VERSION" == "22.04" ) ]]; then
		sudo $PACKAGE_MANAGER install scaleft-rdp-transcoder
		createSftGwConfigRDP
	else
		createSftdConfig
	fi
	if [[ $DISTRIBUTION == "freebsd" ]];then
		sudo pkg install -y ./scaleft-gateway-$highest_version.pkg
	else
		sudo $PACKAGE_MANAGER install scaleft-gateway
	fi
}

# Main script body below

INSTALLED_SOMETHING=false

# Parse command line options for overrides to static variable sets
getOptions

# If something needs to be installed, collect necessary information and update the package manager
if [[ "$INSTALL_SERVER_TOOLS" == "true" ]] || [[ "$INSTALL_GATEWAY" == "true" ]] || [[ "$INSTALL_CLIENT_TOOLS" == "true"]];then
	getOsData
	updatePackageManager
fi

# Perform necessary steps to install ASA Server Tools
if [[ "$INSTALL_SERVER_TOOLS" == "true" ]];then
	getServerName
	createSftdConfig
	createSftdEnrollmentToken
	installSftd
	INSTALLED_SOMETHING=true
fi

# Perform necessary steps to install ASA gateway
if [[ "$INSTALL_GATEWAY" == "true" ]];then
	createSftGatewaySetupToken
	installSft-Gateway
	INSTALL_CLIENT_TOOLS=true
	INSTALLED_SOMETHING=true
fi

# Perform necessary steps to install ASA Client Tools
if [[ "$INSTALL_CLIENT_TOOLS" == "true" ]];then
	installSft
	INSTALLED_SOMETHING=true
fi

if [[ "$INSTALLED_SOMETHING" == "false" ]];then
	echo "No moduled selected for installation, exiting."
	exit 1
fi
exit 0
