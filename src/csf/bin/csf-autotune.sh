#!/usr/bin/env bash
# ==============================================================================
# ConfigServer Security & Firewall - Responsive Resource Allocation Engine
# Architecture: Aetherinox CURRENT Specification (Dynamic Hardware Offload)
# ==============================================================================

CONF_FILE="/etc/csf/csf.conf"
KERNEL_TUNE_FILE="/etc/sysctl.d/99-csf-tuning.conf"
RPS_SERVICE_FILE="/etc/systemd/system/csf-nic-accelerator.service"

echo "[+] Initializing Responsive Resource Allocation Engine..."

# --- 1. Dynamic Hardware Detection ---
CPU_CORES=$(nproc)
RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')

echo "--------------------------------------------------"
echo "System Hardware Profile Detected:"
echo "  CPU Cores : $CPU_CORES"
echo "  Total RAM : $RAM_MB MB"
echo "--------------------------------------------------"

# --- 2. Prerequisite Driver Pack Activator ---
echo "[+] Activating xtables-addons driver pack & conntrack elements..."
DRIVER_PACK=(
    "xt_TARPIT" "xt_CHAOS" "xt_DELUDE" "xt_ECHO" 
    "xt_geoip" "xt_ipp2p" "xt_account" "xt_pknock" 
    "xt_TEE" "xt_IPMARK" "xt_SYSRQ" "xt_dhcpmac" 
    "xt_dnetmap" "xt_LOGMARK" "ip_set" "ip_set_hash_ip" 
    "ip_set_hash_net" "nf_conntrack"
)

for module in "${DRIVER_PACK[@]}"; do
    if ! lsmod | grep -q "^${module}" &>/dev/null; then
        modprobe "$module" 2>/dev/null
    fi
done

# --- 3. Mathematical Resource Boundary Scaling ---
# Calculate the dedicated 12% memory boundary allocations dynamically
CONNTRACK_MAX=$((RAM_MB * 64))
CONNTRACK_BUCKETS=$((CONNTRACK_MAX / 4))

# Establish dynamic sizing limits for ipset hash structures based on RAM capacity
if [ "$RAM_MB" -gt 131072 ]; then
    IPSET_HASH=1048576
    IPSET_MAX=4194304
else
    # Fallback thresholds for regular standard-tier profiles
    M_PAGES=$((RAM_MB * 1024 / 4))
    IPSET_HASH=$((M_PAGES / 16))
    IPSET_MAX=$((IPSET_HASH * 4))
fi

echo "[+] Computing boundary optimizations..."
echo "    > Assigned net.netfilter.nf_conntrack_max     = $CONNTRACK_MAX"
echo "    > Assigned net.netfilter.nf_conntrack_buckets = $CONNTRACK_BUCKETS"
echo "    > Assigned LF_IPSET_HASHSIZE                  = $IPSET_HASH"
echo "    > Assigned LF_IPSET_MAXELEM                   = $IPSET_MAX"

# --- 4. Apply Kernel-Level Hardening & Sizing Structures ---
cat << EOF > "$KERNEL_TUNE_FILE"
# Auto-Generated via Revolutionary Technology Responsive Resource Allocation Engine
net.netfilter.nf_conntrack_max=$CONNTRACK_MAX
net.netfilter.nf_conntrack_buckets=$CONNTRACK_BUCKETS
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.core.somaxconn=65535
EOF

sysctl -p "$KERNEL_TUNE_FILE" &>/dev/null

# --- 5. Update CSF Configurations Dynamically ---
update_csf_setting() {
    local key=$1
    local val=$2
    if grep -q "^\s*$key\s*=" "$CONF_FILE"; then
        sed -i -E "s|^(\s*$key\s*=\s*)\".*\"|\1\"$val\"|" "$CONF_FILE"
    fi
}

echo "[+] Writing high-performance defaults to configuration plane..."
update_csf_setting "RESTRICT_SYSLOG" "3"
update_csf_setting "PT_LIMIT" "0"       # Completely disables slow legacy process tracking
update_csf_setting "CC_LOOKUPS" "4"     # Employs high-speed binary search CSV mapping
update_csf_setting "LF_DISTFTP" "5"
update_csf_setting "LF_IPSET" "1"
update_csf_setting "LF_IPSET_HASHSIZE" "$IPSET_HASH"
update_csf_setting "LF_IPSET_MAXELEM" "$IPSET_MAX"

# --- 6. Persist NIC Offloads and Receive Packet Steering (RPS) ---
NIC=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
if [ -n "$NIC" ]; then
    echo "[+] Deploying persistent NIC acceleration engine for $NIC..."
    
    cat << EOF > "$RPS_SERVICE_FILE"
[Unit]
Description=CSF Full NIC Accelerator (RPS & Ethtool Offloads)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c "
    NIC=\$(ip route get 1.1.1.1 2>/dev/null | awk '{print \$5; exit}');
    if [ -n \"\$NIC\" ]; then
        # Compute exact hexadecimal core affinity mask to balance network loops
        CPU_CORES=\$(nproc);
        CPU_MASK=\$(printf '%x' \$((2**CPU_CORES - 1)));
        for queue in /sys/class/net/\$NIC/queues/rx-*; do
            [ -f \"\$queue/rps_cpus\" ] && echo \"\$CPU_MASK\" > \"\$queue/rps_cpus\";
        done;
        
        # Offload routing and structural segmentation processing tasks directly to the NIC microprocessors
        if command -v ethtool &> /dev/null; then
            ethtool -K \$NIC rx-checksum on;
            ethtool -K \$NIC tx-checksum-ipv4 on;
            ethtool -K \$NIC tx-checksum-ipv6 on;
            ethtool -K \$NIC tcp-segmentation-offload on;
            ethtool -K \$NIC generic-segmentation-offload on;
            ethtool -K \$NIC generic-receive-offload on;
        fi
    fi
"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now csf-nic-accelerator.service &>/dev/null
    echo "    > Managed microprocessors activated (Blue Light Active)."
fi

echo "[+] Responsive Resource Allocation Tuning Complete."
