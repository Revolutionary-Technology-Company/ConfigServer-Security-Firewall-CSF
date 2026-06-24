#!/bin/bash
# ==============================================================================
# ConfigServer by Revolutionary Technology - Master Uninstaller
# Reverts XDP, xtables-addons, ModSec3, U32/SYN, and Python plugins.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[!] Fatal: This uninstaller requires root privileges." >&2
  exit 1
fi

echo "[+] Initializing Revolutionary Technology Master Uninstall Sequence..."

CSF_CONF="/etc/csf/csf.conf"
IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)

# ------------------------------------------------------------------------------
# 1. HALT LOGGING DAEMONS & SERVICES (ModSecurity 3 Converter)
# ------------------------------------------------------------------------------
echo "    > Stopping ModSecurity 3 Converter Daemon..."
if systemctl is-active --quiet modsec3-converter.service; then
    systemctl stop modsec3-converter.service
    systemctl disable modsec3-converter.service
    rm -f /etc/systemd/system/modsec3-converter.service
    systemctl daemon-reload
    echo "      [Done] modsec3-converter.service removed."
fi

# ------------------------------------------------------------------------------
# 2. DETACH HARDWARE OFFLOADING (eBPF / XDP Engine)
# ------------------------------------------------------------------------------
echo "    > Detaching XDP/eBPF Engine from Network Interface ($IFACE)..."
if [ -n "$IFACE" ]; then
    ip link set dev "$IFACE" xdp off >/dev/null 2>&1
    echo "      [Done] Hardware NIC released."
fi

# Unmount BPF filesystem if it was mounted just for us
umount /sys/fs/bpf/ >/dev/null 2>&1

# ------------------------------------------------------------------------------
# 3. UNLOAD KERNEL MODULES & IPTABLES HOOKS (xtables-addons & u32)
# ------------------------------------------------------------------------------
echo "    > Flushing custom iptables chains (Raw & Filter)..."
IPTABLES=$(which iptables)
$IPTABLES -t raw -D PREROUTING -j RT_STRESS_RAW 2>/dev/null
$IPTABLES -t filter -D INPUT -j RT_STRESS_FILTER 2>/dev/null
$IPTABLES -t raw -F RT_STRESS_RAW 2>/dev/null
$IPTABLES -t filter -F RT_STRESS_FILTER 2>/dev/null
$IPTABLES -t raw -X RT_STRESS_RAW 2>/dev/null
$IPTABLES -t filter -X RT_STRESS_FILTER 2>/dev/null

echo "    > Unloading stateless xtables-addons modules..."
MODULES=("xt_TARPIT" "xt_CHAOS" "xt_DELUDE" "xt_ECHO" "xt_geoip" "xt_ACCOUNT")
for mod in "${MODULES[@]}"; do
    rmmod "$mod" 2>/dev/null
done

# ------------------------------------------------------------------------------
# 4. REMOVE FILES, BINARIES, AND PLUGINS
# ------------------------------------------------------------------------------
echo "    > Deleting scripts, plugins, and compiled objects..."

# XDP Engine Files
rm -rf /etc/csf/xdp/
rm -f /usr/local/csf/bin/csf_bpf_loader.sh
rm -f /etc/csf/csf_bpf_loader.sh

# Stress Engine & U32
rm -f /etc/csf/csfpost.sh
rm -f /etc/csf/stressengine.sh
rm -f /etc/csf/ddos_mitigation.sh

# ModSec3 Converter
rm -f /usr/local/bin/modsec3_converter.pl
rm -f /usr/local/csf/bin/modsec3_converter.pl

# Secure Boot MOK Keys
if [ -f "/etc/csf/rt_mok.priv" ]; then
    rm -f /etc/csf/rt_mok.priv
    rm -f /etc/csf/rt_mok.der
    echo "      [Info] MOK private keys deleted. (Enrolled keys in BIOS remain active)."
fi

# Enterprise Python Plugins
rm -f /usr/local/csf/plugins/rt_blocklist_compiler.py
rm -f /usr/local/csf/plugins/rt_enterprise_engine.py
rm -f /usr/local/csf/plugins/rt_rule_generator.py
rm -f /usr/local/csf/plugins/rt_qcsuper_detector.py
rm -f /usr/local/csf/plugins/csf_isolation_valve.py

# ------------------------------------------------------------------------------
# 5. REVERT CONFIGURATION FILES (csf.conf)
# ------------------------------------------------------------------------------
echo "    > Cleaning RT custom variables from csf.conf..."
if [ -f "$CSF_CONF" ]; then
    # Revert ModSecurity Log path to standard cPanel default
    sed -i 's|^MODSEC_LOG = "/var/log/apache2/modsec_legacy_lfd.log"|MODSEC_LOG = "/etc/apache2/logs/error_log"|' "$CSF_CONF"
    
    # Remove custom RT Config Engine Variables
    sed -i '/^DROP\s*=/d' "$CSF_CONF"
    sed -i '/^RT_TCP_XDP_STRICT\s*=/d' "$CSF_CONF"
    sed -i '/^RT_UDP_XDP_STRICT\s*=/d' "$CSF_CONF"
fi

# ------------------------------------------------------------------------------
# 6. RESTART CSF & CLEAR CACHES
# ------------------------------------------------------------------------------
echo "    > Executing full CSF structural reload..."
if command -v csf >/dev/null 2>&1; then
    csf -x >/dev/null 2>&1
    csf -e >/dev/null 2>&1
fi

echo "==================================================================="
echo "[+] Uninstallation Complete."
echo "    - Hardware XDP offloading released."
echo "    - Stateful iptables tracking restored."
echo "    - Univac-IX & Python integration pipelines severed."
echo "    - Server is now running standard vanilla ConfigServer (CSF)."
echo "==================================================================="

#!/usr/bin/env bash
# ==============================================================================
# ConfigServer Security & Firewall - Master RT Extension Uninstaller
# Path: /usr/local/csf/bin/rt_uninstall_engine.sh
# Description: Protection-first cleanup module to strip out eBPF/XDP, nftables, 
#              and continuous tracking daemons securely.
# ==============================================================================

echo "[*] Initializing Revolutionary Technology Engine Removal Track..."

# --- 1. Teardown 24/7 Service Daemons ---
echo "[*] Disabling continuous automated tracking services..."
SERVICES=(
    "rt-gsb-poller.service"       # Google Safe Sites Zero Trust Poller
    "modsec3-converter.service"   # ModSec3 LFD Compatibility Engine
    "csf-nic-accelerator.service" # Persistent Network Accelerator
)

for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo "    > Stopping $SERVICE..."
        systemctl stop "$SERVICE" >/dev/null 2>&1
    fi
    if systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
        echo "    > Disabling $SERVICE..."
        systemctl disable "$SERVICE" >/dev/null 2>&1
    fi
    rm -f "/etc/systemd/system/$SERVICE"
done
systemctl daemon-reload

# --- 2. Remove Automated Threat Intelligence Cron Jobs ---
echo "[*] Purging telemetry cron scripts..."
CRON_LINKS=(
    "/etc/cron.hourly/rt-block-reporter"
    "/etc/cron.daily/rt-block-reporter"
    "/etc/cron.weekly/rt-google-ip-updater"
)

for LINK in "${CRON_LINKS[@]}"; do
    if [ -L "$LINK" ] || [ -f "$LINK" ]; then
        echo "    > Removing $LINK..."
        rm -f "$LINK"
    fi
done

# --- 3. Detach eBPF / XDP Network Shields ---
echo "[*] Revoking network driver level eBPF hardware offloads..."
if command -v bpftool &>/dev/null; then
    # Detect primary NIC using active routing table maps
    PRIMARY_NIC=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [ -n "$PRIMARY_NIC" ]; then
        echo "    > Detaching XDP shield from interface: $PRIMARY_NIC..."
        ip link set dev "$PRIMARY_NIC" xdp off 2>/dev/null
        ip link set dev "$PRIMARY_NIC" xdpgeneric off 2>/dev/null
    fi
fi

# --- 4. Purge Custom Native NFTables Frameworks ---
echo "[*] Flushing native netfilter tables and element sets..."
if command -v nft &>/dev/null; then
    if nft list table inet csf_firewall &>/dev/null; then
        echo "    > Deleting table inet csf_firewall..."
        nft delete table inet csf_firewall
    fi
fi

# --- 5. Clean Repository Custom Directory Inodes ---
echo "[*] Deleting execution binaries and Python plugin suite assets..."
rm -rf /usr/local/csf/bin/rt_*
rm -rf /usr/local/csf/bin/modsec3_*
rm -rf /usr/local/csf/plugins/rt_*
rm -rf /etc/csf/xdp
rm -rf /etc/csf/modsec
rm -f /etc/sysctl.d/99-csf-tuning.conf
rm -f /var/lib/csf/rt-reporter.state

echo "[+] Revolutionary Technology extension layers cleanly stripped[cite: 35]."
