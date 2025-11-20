#!/bin/bash
# #
#   @script             Revolutionary Technology AppArmor Installer
#   @description        Loads hardening profiles for SSH, HTTP, and Exim.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

PROFILE_DIR="/etc/apparmor.d"
SRC_DIR="./profiles"

echo "[RT-AppArmor] Checking for AppArmor support..."

if ! command -v apparmor_status >/dev/null 2>&1; then
    echo "[RT-AppArmor] AppArmor not found. Attempting to install..."
    if [ -f /usr/bin/apt-get ]; then
        apt-get install -y apparmor apparmor-utils >/dev/null 2>&1
    elif [ -f /usr/bin/yum ]; then
        yum install -y apparmor-parser >/dev/null 2>&1
    fi
fi

if ! command -v apparmor_status >/dev/null 2>&1; then
    echo "[RT-AppArmor] Failed to install/detect AppArmor. Skipping Application Hardening."
    exit 0
fi

echo "[RT-AppArmor] Installing Profiles..."

# Ensure profile directory exists
if [ -d "$SRC_DIR" ]; then
    # Copy profiles
    cp "$SRC_DIR/usr.sbin.sshd" "$PROFILE_DIR/"
    cp "$SRC_DIR/usr.sbin.httpd" "$PROFILE_DIR/"
    cp "$SRC_DIR/usr.sbin.exim" "$PROFILE_DIR/"

    # Enforce Profiles
    echo "[RT-AppArmor] Enforcing SSHD Profile..."
    aa-enforce "$PROFILE_DIR/usr.sbin.sshd"

    echo "[RT-AppArmor] Enforcing HTTPD Profile..."
    aa-enforce "$PROFILE_DIR/usr.sbin.httpd"

    echo "[RT-AppArmor] Enforcing EXIM Profile..."
    aa-enforce "$PROFILE_DIR/usr.sbin.exim"

    echo "[RT-AppArmor] Reloading AppArmor..."
    service apparmor reload
    
    echo "[RT-AppArmor] Application Hardening Active."
else
    echo "[RT-AppArmor] Profile source directory not found. Skipping."
fi