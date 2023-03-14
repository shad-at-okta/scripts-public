#!/bin/bash

SERVER_ENROLLMENT_TOKEN=""
GATEWAY_TOKEN=""
INSTALL_SERVER_TOOLS=false
INSTALL_GATEWAY=false
INSTALL_CLIENT=false
ENVIRONMENT="prod"

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
      INSTALL_CLIENT=true
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

echo "Install server tools: $INSTALL_SERVER_TOOLS"
echo "Server enrollment token:$SERVER_ENROLLMENT_TOKEN"
echo "Install gateway: $INSTALL_GATEWAY"
echo "Gateway token:$GATEWAY_TOKEN"
echo "Install client:$INSTALL_CLIENT"
echo "Code branch to install:$ENVIRONMENT"
