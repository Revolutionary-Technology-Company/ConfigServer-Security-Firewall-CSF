#!/usr/bin/env bash
# ==============================================================================
# ConfigServer Security & Firewall - Secure License & Update Orchestrator
# Path: /usr/local/csf/bin/rt-csf-update.sh
# ==============================================================================

CSF_CONFIG="/etc/csf/csf.conf"
INSTALL_DIR="/usr/src/csf-latest"
SHOP_URL="https://configserver.shop/api/v1"

echo "[*] Initializing Secure Product Verification Interface..."

if [ ! -f "$CSF_CONFIG" ]; then
    echo "[-] Fatal Error: Configuration array missing at $CSF_CONFIG."
    exit 1
fi

# Extract and isolate the license key string from csf.conf[cite: 36]
LICENSE_KEY=$(grep -E "^RT_LICENSE_KEY" "$CSF_CONFIG" | sed -E 's/RT_LICENSE_KEY = "(.*)"/\1/')

if [ -z "$LICENSE_KEY" ]; then
    echo "[-] Error: No active key found in $CSF_CONFIG."[cite: 36]
    echo "    Please provision 'RT_LICENSE_KEY' to enable secure mirrors."[cite: 36]
    exit 1
fi

# 1. Contact the version validation endpoint[cite: 35]
echo "[*] Authenticating hardware footprint against configserver.shop..."
REMOTE_VER=$(curl -s -f -X POST -d "license_key=$LICENSE_KEY" "$SHOP_URL/version_check.php")

if [ $? -ne 0 ] || [ -z "$REMOTE_VER" ]; then
    echo "[!] Authentication Rejected: Invalid serial signature or connection timeout."[cite: 36]
    exit 1
fi

CURRENT_VER=$(cat /etc/csf/version.txt 2>/dev/null || echo "0.00")
echo "    > Local Version : v$CURRENT_VER"
echo "    > Remote Version: v$REMOTE_VER"

if [ "$CURRENT_VER" == "$REMOTE_VER" ]; then
    echo "[+] System is running the latest authenticated release layer."
    exit 0
fi

# 2. Key is valid and code is stale — execute transaction download[cite: 35, 36]
echo "[*] Transferring encrypted software archive assets..."
rm -rf "$INSTALL_DIR" /usr/src/csf-latest.tgz[cite: 36]
mkdir -p "$INSTALL_DIR"[cite: 36]

curl -s -f -X POST \
     -d "license_key=$LICENSE_KEY" \
     -o "$INSTALL_DIR/csf-latest.tgz" \
     "$SHOP_URL/downloader.php"[cite: 35, 36]

if [ ! -s "$INSTALL_DIR/csf-latest.tgz" ]; then
    echo "[-] Core Sync Error: Received empty payload from update mirror."[cite: 36]
    exit 1
fi

# 3. Unpack and overwrite binaries natively[cite: 36]
echo "[*] Deploying signed v2.15 upgrade packages..."
tar -xzf "$INSTALL_DIR/csf-latest.tgz" -C "$INSTALL_DIR"[cite: 36]
INSTALLER_SRC=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d)[cite: 36]

cd "$INSTALLER_SRC" || exit 1[cite: 36]
sh install.sh[cite: 36]

# Clean system footprints
rm -rf "$INSTALL_DIR" /usr/src/csf-latest.tgz[cite: 36]
echo "[+] Upgrade to v$REMOTE_VER complete."[cite: 36]
