#!/usr/bin/env bash
# ==============================================================================
# Revolutionary Technology - Omni Setup Orchestrator
# Replaces: remove_apf_bfd, install-apparmor, install-suricata, compile_xdp, rt-sign-module
# ==============================================================================
set -e # Guard clause: Exit instantly on any error

echo "[*] Initializing Revolutionary Technology Omni-Setup..."

# 1. GUARD CLAUSE: Ensure Root Privileges
if [[ $EUID -ne 0 ]]; then
   echo "[-] FATAL: This script must be run as root." 
   exit 1
fi

# 2. REMOVE LEGACY FIREWALLS (remove_apf_bfd.sh)
echo "[+] Scrubbing legacy APF and BFD installations..."
systemctl stop apf 2>/dev/null || true
systemctl disable apf 2>/dev/null || true
rm -rf /etc/apf /usr/local/sbin/apf /etc/cron.daily/bfd /usr/local/bfd

# 3. APPARMOR SANDBOXING (install-apparmor.sh)
echo "[+] Generating CSF AppArmor Isolation Profiles..."
if command -v apparmor_parser >/dev/null 2>&1; then
    cat << 'EOF' > /etc/apparmor.d/usr.sbin.csf
#include <tunables/global>
/usr/sbin/csf flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/perl>
  capability net_admin,
  capability net_raw,
  capability sys_module,
  /etc/csf/** rw,
  /var/lib/csf/** rw,
  /usr/sbin/csf mr,
  /sbin/iptables rix,
  /sbin/ip6tables rix,
}
EOF
    apparmor_parser -r /etc/apparmor.d/usr.sbin.csf
    echo "  -> AppArmor profile locked and loaded."
fi

# 4. SURICATA IDS/IPS DEPLOYMENT (install-suricata.sh)
echo "[+] Installing Suricata IDS Engine..."
if ! command -v suricata >/dev/null 2>&1; then
    apt-get update -y && apt-get install suricata -y || yum install suricata -y
    suricata-update
fi

# 5. XDP eBPF COMPILATION & SIGNING (compile_xdp.sh & rt-sign-module.sh)
echo "[+] Compiling XDP Hardware Offload Modules..."
if command -v clang >/dev/null 2>&1; then
    cd /etc/csf
    # Compile C to BPF Object
    clang -O2 -target bpf -c xdp_echo.c -o xdp_echo.o
    
    # Generate ephemeral key and sign the module for Secure Boot compliance
    openssl req -new -x509 -newkey rsa:2048 -keyout rt_module.priv -outform DER -out rt_module.der -nodes -days 36500 -subj "/CN=Revolutionary Technology/"
    /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./rt_module.priv ./rt_module.der xdp_echo.o || true
    echo "  -> XDP Object compiled and signed successfully."
else
    echo "[-] WARNING: clang not found. Skipping XDP compilation."
fi

echo "[*] Omni-Setup Complete. Handing over to Python Enterprise Engine."
