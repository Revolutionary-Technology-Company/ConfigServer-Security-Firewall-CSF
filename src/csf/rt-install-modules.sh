#!/bin/bash
# Aetherinox Rebuild - Secure Boot & xtables-addons Installer
# Run this during the CSF installation phase.

echo "[+] Initializing Aetherinox xtables-addons Installer..."

# 1. Install prerequisites
echo "[+] Installing compilation dependencies..."
if [ -x "$(command -v dnf)" ]; then
    dnf install -y gcc make kernel-devel kernel-headers perl mokutil openssl
elif [ -x "$(command -v apt-get)" ]; then
    apt-get install -y gcc make linux-headers-$(uname -r) perl mokutil openssl
fi

# (Assume xtables-addons source is downloaded and extracted to /usr/src/xtables-addons)
# cd /usr/src/xtables-addons && ./configure && make && make install

# 2. Check Secure Boot State
if mokutil --sb-state | grep -iq "enabled"; then
    echo "[!] Secure Boot is ENABLED. Initializing Module Signing Protocol..."
    
    MOK_PRIV="/etc/csf/rt_mok.priv"
    MOK_DER="/etc/csf/rt_mok.der"
    MOK_SUBJ="/CN=Aetherinox Firewall Module Signing Key/"
    SIGN_FILE=$(find /usr/src/kernels/$(uname -r) -name sign-file | head -n 1)

    # Generate persistent key if it doesn't exist
    if [ ! -f "$MOK_PRIV" ]; then
        echo "    > Generating new RSA MOK Key..."
        openssl req -new -x509 -newkey rsa:2048 -keyout "$MOK_PRIV" \
            -outform DER -out "$MOK_DER" -nodes -days 3650 \
            -subj "$MOK_SUBJ"
    else
        echo "    > Existing MOK Key found at $MOK_PRIV"
    fi

    # 3. Sign the ENTIRE xtables-addons driver pack
    MODULES_TO_SIGN=("xt_TARPIT" "xt_CHAOS" "xt_DELUDE" "xt_ECHO" "xt_geoip" "xt_ipp2p" "xt_ACCOUNT" "xt_SYSRQ")
    
    echo "    > Signing Kernel Modules..."
    for mod in "${MODULES_TO_SIGN[@]}"; do
        MODULE_PATH=$(find /lib/modules/$(uname -r)/ -name "${mod}.ko" | head -n 1)
        if [ -n "$MODULE_PATH" ]; then
            if [ -n "$SIGN_FILE" ]; then
                "$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"
                echo "      [Signed] $mod"
            else
                echo "      [ERROR] sign-file binary not found for kernel $(uname -r)!"
            fi
        else
            echo "      [Skip] Module ${mod}.ko not found in kernel tree."
        fi
    done

    # 4. Prompt for one-time reboot & enrollment
    echo "    > Staging MOK for Secure Boot Enrollment..."
    echo "==================================================================="
    echo " ACTION REQUIRED: You must create a one-time password for MOK."
    echo " After completion, REBOOT your server."
    echo " Upon reboot, you will see a blue MOKManager screen:"
    echo "   1. Select 'Enroll MOK'"
    echo "   2. Select 'Continue'"
    echo "   3. Select 'Yes' and enter the password you are about to create."
    echo "==================================================================="
    mokutil --import "$MOK_DER"
else
    echo "[+] Secure Boot is DISABLED. Skipping kernel module signing."
fi

# Run depmod to register new modules
depmod -a
echo "[+] xtables-addons installation complete."
