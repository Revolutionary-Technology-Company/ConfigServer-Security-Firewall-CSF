#!/bin/sh
#
# Revolutionary Technology CSF Updater
# https://configserver.shop
#

# --- Configuration ---
# The API endpoint on your server that validates keys and sends the file
DOWNLOAD_ENDPOINT="https://configserver.shop/api/v1/download"
CSF_CONFIG="/etc/csf/csf.conf"
INSTALL_DIR="/usr/src/csf-latest"
# --- End Configuration ---

echo "Updating ConfigServer Firewall by Revolutionary Technology..."
echo ""

# 1. Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' is required for secure updates."
    echo "Please install it (e.g., 'yum install curl' or 'apt install curl') and try again."
    exit 1
fi

# 2. Read the License Key from csf.conf
if [ ! -f "$CSF_CONFIG" ]; then
    echo "Error: Config file not found at $CSF_CONFIG."
    exit 1
fi

# Use grep and sed to extract the key value
LICENSE_KEY=$(grep -E "^RT_LICENSE_KEY" $CSF_CONFIG | sed -E 's/RT_LICENSE_KEY = "(.*)"/\1/')

if [ -z "$LICENSE_KEY" ]; then
    echo "Error: No license key found in $CSF_CONFIG."
    echo "Please add your RT_LICENSE_KEY to /etc/csf/csf.conf to enable updates."
    echo "You can get your key from https://configserver.shop"
    exit 1
fi

# 3. Clean up old installation files
echo "Cleaning up old update files..."
rm -rf $INSTALL_DIR
rm -f /usr/src/csf-latest.tgz
mkdir -p $INSTALL_DIR

# 4. Authenticate and Download
echo "Authenticating with configserver.shop..."
if ! curl -s -f -X POST \
     -d "license_key=$LICENSE_KEY" \
     -o $INSTALL_DIR/csf-latest.tgz \
     $DOWNLOAD_ENDPOINT; then
    
    echo "Error: Download failed."
    echo "Please check your license key is active or try again later."
    exit 1
fi

# 5. Extract and Install
echo "Extracting package..."
if ! tar -xzf $INSTALL_DIR/csf-latest.tgz -C $INSTALL_DIR; then
    echo "Error: Failed to extract package."
    exit 1
fi

# Find the installer directory (e.g., 'csf-15.02')
INSTALLER_SRC=$(find $INSTALL_DIR -mindepth 1 -maxdepth 1 -type d)

if [ -z "$INSTALLER_SRC" ]; then
    echo "Error: Could not find installer directory in package."
    exit 1
fi

cd $INSTALLER_SRC

# 6. Run your modified installer
echo "Running Revolutionary Technology installer..."
sh install.sh

# 7. Clean up
echo "Cleaning up..."
rm -rf $INSTALL_DIR
rm -f /usr/src/csf-latest.tgz

echo ""
echo "Update complete."