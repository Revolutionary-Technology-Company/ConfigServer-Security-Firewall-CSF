#!/bin/sh
#
# Revolutionary Technology - Secure Boot Module Signer (v3.1)
# Cross-compatible (RHEL/CentOS/Debian/Ubuntu)
# Updates: Added check to skip reboot if MOK is already enrolled
#

# --- Define Colors ---
esc=$(printf '\033')
end="${esc}[0m"
redl="${esc}[0;91m"
greenl="${esc}[38;5;76m"
yellowl="${esc}[38;5;190m"
greym="${esc}[38;5;244m"

echo -e "    > Secure Boot detected. Starting key generation and signing process..."

# --- Configuration ---
MOK_PRIV="/etc/csf/rt_mok.priv"
MOK_DER="/etc/csf/rt_mok.der"
MOK_SUBJ="/CN=Revolutionary Technology Module Signing Key"

# Detect Kernel Header Path (Cross-Distro)
UNAME_R=$(uname -r)
if [ -d "/usr/src/kernels/$UNAME_R" ]; then
    KBUILD_PATH="/usr/src/kernels/$UNAME_R"  # RHEL/CentOS
elif [ -d "/usr/src/linux-headers-$UNAME_R" ]; then
    KBUILD_PATH="/usr/src/linux-headers-$UNAME_R" # Debian/Ubuntu
else
    KBUILD_PATH="/usr/src/linux" # Fallback
fi

MODULES_TO_SIGN=(
    "xt_TARPIT" "xt_ECHO" "xt_CHAOS" "xt_DELUDE" "xt_geoip"
    "xt_ipp2p" "xt_account" "xt_pknock" "xt_TEE" "xt_IPMARK"
    "xt_SYSRQ" "xt_dhcpmac" "xt_dnetmap" "xt_LOGMARK"
    "ip_set" "ip_set_hash_ip" "ip_set_hash_net"
)

# 1. Check for kernel headers
if [ ! -d "$KBUILD_PATH" ]; then
    echo -e "    ${redl}ERROR:${greym} Kernel headers not found."
    echo -e "    Checked: $KBUILD_PATH"
    echo -e "    Please install headers (yum install kernel-devel / apt install linux-headers-$(uname -r))."
    echo "1" > /tmp/rt_sign_failed
    exit 0
fi

# 2. Find the sign-file script
SIGN_FILE="$KBUILD_PATH/scripts/sign-file"
if [ ! -x "$SIGN_FILE" ]; then
    # Deep search fallback
    SIGN_FILE=$(find /usr/src -name sign-file -type f -executable | head -n 1)
    if [ ! -x "$SIGN_FILE" ]; then
        echo -e "    ${redl}ERROR:${greym} 'sign-file' script not found. Cannot sign modules."
        echo "1" > /tmp/rt_sign_failed
        exit 0
    fi
fi

# 3. Generate a new key if one doesn't exist
if [ ! -f "$MOK_PRIV" ]; then
    echo -e "    > No existing key found. Generating new MOK..."
    openssl req -new -x509 -newkey rsa:2048 -keyout "$MOK_PRIV" \
            -outform DER -out "$MOK_DER" -nodes -days 3650 \
            -subj "$MOK_SUBJ" 2>/dev/null
else
    echo -e "    > Using existing MOK at $MOK_PRIV"
fi

# 4. Loop and sign all modules
echo -e "    > Locating and signing all required modules..."
for module in "${MODULES_TO_SIGN[@]}"; do
    # Find module (handle .ko and .ko.xz compressed modules)
    MODULE_PATH=$(find /lib/modules/$(uname -r)/ -name "${module}.ko*" | head -n 1)
    
    if [ -z "$MODULE_PATH" ]; then
        echo -e "    ${yellowl}[WARN]${greym} Module $module not found. Skipping."
    else
        if [[ "$MODULE_PATH" == *.ko ]]; then
             # Only output if we are actually signing to keep logs clean
             "$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"
        fi
    fi
done

# 5. Check enrollment status (FIXED LOGIC)
echo -e "    > Verifying key enrollment status..."

# mokutil --test returns 0 if the key is ALREADY enrolled, and non-zero if it is not.
if mokutil --test "$MOK_DER" >/dev/null 2>&1; then
    echo -e "    ${greenl}[OK]${greym} Key is already enrolled in Secure Boot."
    echo -e "    ${greenl}[OK]${greym} Modules signed and ready. No reboot required."
    # We do NOT create the reboot required flag here
else
    echo -e "    > Key is NOT enrolled. Staging for enrollment..."
    
    if ! mokutil --import "$MOK_DER"; then
        echo -e "    ${redl}ERROR:${greym} mokutil --import failed. The key could not be staged."
        echo "1" > /tmp/rt_sign_failed
        exit 0
    fi

    echo -e "    ${yellowl}--- ACTION REQUIRED ---${end}"
    echo -e "    A new password is required for the MOK enrollment."
    echo -e "    You will be asked for this password ${yellowl}one time${end} during the reboot."
    echo -e "    Please enter a new password now (it will not be echoed):"
    
    # Flag that a reboot is actually needed this time
    echo "1" > /tmp/rt_reboot_required
fi