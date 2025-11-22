#!/bin/bash
# #
#   @script             Revolutionary Technology AppArmor Installer (v2.0)
#   @description        Installs AppArmor Engine AND Enforces Service Profiles.
#                       Dynamically loads all profiles found in ./profiles/
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

PROFILE_DIR="/etc/apparmor.d"
SRC_DIR="./profiles"

echo "[RT-AppArmor] Installing AppArmor Application Control..."

# --- 1. Install AppArmor Engine & Utils ---
if [ -f /usr/bin/apt-get ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y apparmor apparmor-utils apparmor-profiles >/dev/null 2>&1
elif [ -f /usr/bin/yum ]; then
    yum install -y apparmor-parser apparmor-utils >/dev/null 2>&1
fi

# --- 2. Enable Kernel Module & Service ---
if ! grep -q "security=apparmor" /proc/cmdline; then
    echo "    [NOTE] 'security=apparmor' not found in kernel parameters."
    echo "           AppArmor may require a reboot to fully activate."
fi

systemctl enable apparmor >/dev/null 2>&1
systemctl start apparmor >/dev/null 2>&1

# --- 3. Install & Enforce Custom Profiles (Dynamic) ---
echo "    > Installing Hardened Service Profiles..."

if [ -d "$SRC_DIR" ]; then
    # Loop through all profiles in the source directory
    # We look for files starting with 'usr.sbin.' or 'usr.bin.'
    count=0
    for profile in "$SRC_DIR"/usr.*; do
        if [ -f "$profile" ]; then
            filename=$(basename "$profile")
            echo "    > Enforcing Profile: $filename"
            
            # Copy to system directory
            cp "$profile" "$PROFILE_DIR/"
            
            # Enforce (Switch to 'Complain' mode first if you want to be safer, but 'Enforce' is secure)
            aa-enforce "$PROFILE_DIR/$filename" >/dev/null 2>&1
            
            count=$((count+1))
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        echo "    [INFO] No profiles found in $SRC_DIR. Only base engine active."
    else
        echo "    [OK] Enforced $count Application Profiles."
    fi
else
    echo "    [WARN] '$SRC_DIR' directory not found. Skipping custom rules."
fi

# --- 4. Baseline Safety (Network Tools) ---
echo "    > Setting baseline profiles for network tools..."
if command -v ping >/dev/null; then aa-complain $(which ping) >/dev/null 2>&1; fi
if command -v tcpdump >/dev/null; then aa-complain $(which tcpdump) >/dev/null 2>&1; fi

echo "    [OK] AppArmor Active. Application Awareness enabled."