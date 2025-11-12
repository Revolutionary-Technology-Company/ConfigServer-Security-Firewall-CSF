#!/bin/sh
#
# Revolutionary Technology - Secure Boot Module Signer (v2)
# This script generates a key, signs the xt_TARPIT module, and
# stages the key for MOK enrollment.
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

# 1. Check for kernel headers (needed for 'sign-file')
if [ ! -d "$KBUILD_PATH" ]; then
    echo -e "    ${redl}ERROR:${greym} Kernel headers not found at $KBUILD_PATH."
    echo -e "    Please install them (e.g., 'yum install kernel-devel-$(uname -r)') and re-run the installer."
    echo "1" > /tmp/rt_tarpit_failed
    exit 0
fi

# 2. Find the sign-file script
SIGN_FILE="$KBUILD_PATH/scripts/sign-file"
if [ ! -x "$SIGN_FILE" ]; then
    SIGN_FILE=$(find /usr/src/kernels/ -name sign-file | head -n 1) # Fallback search
    if [ ! -x "$SIGN_FILE" ]; then
        echo -e "    ${redl}ERROR:${greym} 'sign-file' script not found. Cannot sign module."
        echo "1" > /tmp/rt_tarpit_failed
        exit 0
    fi
fi

# 3. Find the module
MODULE_PATH=$(find /lib/modules/$(uname -r)/ -name xt_TARPIT.ko | head -n 1)
if [ -z "$MODULE_PATH" ]; then
    echo -e "    ${redl}ERROR:${greym} xt_TARPIT.ko module not found. DKMS may have failed."
    echo "1" > /tmp/rt_tarpit_failed
    exit 0
fi
echo -e "    > Found module at: $MODULE_PATH"

# 4. Generate a new key if one doesn't exist
if [ ! -f "$MOK_PRIV" ]; then
    echo -e "    > No existing key found. Generating new MOK..."
    openssl req -new -x509 -newkey rsa:2048 -keyout "$MOK_PRIV" \
            -outform DER -out "$MOK_DER" -nodes -days 3650 \
            -subj "$MOK_SUBJ"
else
    echo -e "    > Using existing MOK at $MOK_PRIV"
fi

# 5. Sign the module
echo -e "    > Signing module with our key..."
"$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"

echo -e "    ${greenl}> Module successfully signed.${end}"

# 6. Stage the key for enrollment
echo -e "    > Staging key for enrollment (mokutil)..."
if ! mokutil --import "$MOK_DER"; then
    echo -e "    ${redl}ERROR:${greym} mokutil --import failed. The key could not be staged."
    echo "1" > /tmp/rt_tarpit_failed
    exit 0
fi

echo -e "    ${yellowl}--- ACTION REQUIRED ---${end}"
echo -e "    A new password is required for the MOK enrollment."
echo -e "    You will be asked for this password ${yellowl}one time${end} during the reboot."
echo -e "    Please enter a new password now (it will not be echoed):"
# mokutil --import will prompt the user for a password here.

echo -e "    ${greenl}> Key enrollment has been staged!${end}"
echo "1" > /tmp/rt_reboot_required