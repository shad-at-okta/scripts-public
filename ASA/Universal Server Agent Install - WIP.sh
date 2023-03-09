#!/bin/bash

# Get distribution name
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

case "$DISTRIBUTION" in
  amazonlinux|rhel|centos|alma|fedora)
    echo "Running block of code for Amazon Linux, RHEL, CentOS, Alma, or Fedora"
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
    
    sudo dnf update -qy

    sudo dnf install scaleft-server-tools
    
    ;;
  ubuntu|debian)
    echo "Running block of code for Ubuntu or Debian"
	sudo apt-get update -qy
	sudo apt-get install -qy curl gpg
	curl -fsSL https://dist.scaleft.com/GPG-KEY-OktaPAM-2023 | gpg --dearmor | sudo tee /usr/share/keyrings/oktapam-2023-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/oktapam-2023-archive-keyring.gpg] https://dist.scaleft.com/repos/deb $CODENAME okta" | sudo tee -a /etc/apt/sources.list
    sudo apt-get update -qy
	sudo apt-cache search scaleft -qy
	sudo apt-get install scaleft-server-tools
    ;;
  *)
    echo "Unrecognized OS type: $DISTRIBUTION"
    ;;
esac




# Print the variables
echo "Distribution: $DISTRIBUTION"
echo "Version: $VERSION"
echo "Code name: $CODENAME"
