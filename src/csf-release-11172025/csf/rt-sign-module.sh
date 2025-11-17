#!/bin/sh
#
# Revolutionary Technology - Secure Boot Module Signer (v3)
#
# This script is now a full xtables-addons driver-pack signer.
# It loops through all required modules and signs them.
#

# --- Define Colors (self-contained) ---
esc=$(printf '\033')
end="${esc}[0m"
redl="${esc}[0;91m"
greenl="${esc}[38;5;76m"
yellowl="${esc}[38;5;190m"
greym="${esc}[38;5;244m"
# --- End Colors ---

echo -e "    > Secure Boot detected. Starting key generation and signing process..."

# --- Configuration ---
MOK_PRIV="/etc/csf/rt_mok.priv"
MOK_DER="/etc/csf/rt_mok.der"
MOK_SUBJ="/CN=Revolutionary Technology Module Signing Key"
KBUILD_PATH="/usr/src/kernels/$(uname -r)"

# [NEW] This is the full list of "drivers" we must sign
# This list MUST match the load_required_modules in csf-autotune.sh
MODULES_TO_SIGN=(
    "xt_TARPIT"
    "xt_ECHO"
    "xt_CHAOS"
    "xt_DELUDE"
    "xt_geoip"
    "xt_ipp2p"
    "xt_account"
    "xt_pknock"
    "xt_TEE"
    "xt_IPMARK"
    "xt_SYSRQ"
    "xt_dhcpmac"
    "xt_dnetmap"
    "xt_LOGMARK"
    "ip_set"
    "ip_set_hash_ip"
    "ip_set_hash_net"
)

# 1. Check for kernel headers (needed for 'sign-file')
if [ ! -d "$KBUILD_PATH" ]; then
    echo -e "    ${redl}ERROR:${greym} Kernel headers not found at $KBUILD_PATH."
    echo -e "    Please install them (e.g., 'yum install kernel-devel-$(uname -r)') and re-run the installer."
    echo "1" > /tmp/rt_sign_failed
    exit 0
fi

# 2. Find the sign-file script
SIGN_FILE="$KBUILD_PATH/scripts/sign-file"
if [ ! -x "$SIGN_FILE" ]; then
    SIGN_FILE=$(find /usr/src/kernels/ -name sign-file | head -n 1) # Fallback search
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
            -subj "$MOK_SUBJ"
else
    echo -e "    > Using existing MOK at $MOK_PRIV"
fi

# 4. [NEW] Loop and sign all modules
echo -e "    > Locating and signing all required modules..."
SIGNING_FAILED=0
for module in "${MODULES_TO_SIGN[@]}"; do
    MODULE_PATH=$(find /lib/modules/$(uname -r)/ -name ${module}.ko | head -n 1)
    if [ -z "$MODULE_PATH" ]; then
        echo -e "    ${yellowl}[WARN]${greym} Module ${module}.ko not found. Skipping."
    else
        echo -e "    > Signing $module at $MODULE_PATH..."
        "$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"
    fi
done

# 5. Stage the key for enrollment
echo -e "    > Staging key for enrollment (mokutil)..."
if ! mokutil --import "$MOK_DER"; then
    echo -e "    ${redl}ERROR:${greym} mokutil --import failed. The key could not be staged."
    echo "1" > /tmp/rt_sign_failed
    exit 0
fi

echo -e "    ${yellowl}--- ACTION REQUIRED ---${end}"
echo -e "    A new password is required for the MOK enrollment."
echo -e "    You will be asked for this password ${yellowl}one time${end} during the reboot."
echo -e "    Please enter a new password now (it will not be echoed):"
# mokutil --the import will prompt the user for a password here.

echo -e "    ${greenl}> Key enrollment has been staged!${end}"
echo "1" > /tmp/rt_reboot_required