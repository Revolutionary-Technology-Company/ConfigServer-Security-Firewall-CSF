#!/bin/bash
# #
#   @script             Revolutionary Technology Stress Engine (v5.2 - Final)
#   @description        Hybrid Driver (XDP) + Kernel (NFT/IPT) Defense Layer.
#                       Enforces Packet Validity, Dynamic Tarpits, and SYN Proxy.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

echo "[RT-StressEngine] Loading Revolutionary Technology Stress Engine..."

# --- CONFIGURATION ---
CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
BPF_LOADER="/usr/local/csf/bin/csf-bpf-loader.sh"

# Detect Tools
NFT=$(which nft 2>/dev/null)
IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")

# Read Config (ReadOnly)
RT_TARPIT_TIMEOUT=$(grep "^RT_TARPIT_TIMEOUT" "$CSF_CONF" | cut -d'"' -f2)
: "${RT_TARPIT_TIMEOUT:=600}" # Default to 10m if not set

# ==============================================================================
# 1. HARDWARE OFFLOADING (XDP/BPF) - Layer 0
# ==============================================================================
# This runs at the driver level. It handles the "Strict UDP" dropping based on
# csf.conf (UDP_IN), so we don't need to do it here.
if [ -f "$BPF_LOADER" ] && [ -x "$BPF_LOADER" ]; then
    echo "[RT-StressEngine] Loading XDP/BPF hardware filters..."
    $BPF_LOADER
else
    echo "[RT-StressEngine] BPF loader not found. Falling back to OS firewall."
fi

# ==============================================================================
# 2. OS FIREWALL SELECTION
# ==============================================================================
MODE="IPTABLES"
if [ ! -z "$NFT" ]; then
    # Check if nftables is usable (kernel support + binary)
    if $NFT list ruleset >/dev/null 2>&1; then
        MODE="NFTABLES"
    fi
fi

echo "[RT-StressEngine] Active Firewall Mode: $MODE"

# ==============================================================================
# 3A. NFTABLES IMPLEMENTATION (Modern)
# ==============================================================================
if [ "$MODE" == "NFTABLES" ]; then
    echo "[RT-StressEngine] Applying Native NFTables Rulesets..."

    # Apply Kernel Hardening (Sysctl) - Validity Enforcement
    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rfc1337=1 >/dev/null 2>&1 # Drop RST packets for TIME-WAIT sockets

    # We use a priority of -10 to run BEFORE standard CSF (filter) rules.
    # This ensures garbage traffic is dropped before CSF wastes CPU logging it.
    $NFT -f - <<EOF
    table inet rt_security {
        # Dynamic Penalty Box (The "Tar Pit" Set)
        set rt_penalty_box {
            type ipv4_addr
            flags dynamic, timeout
            timeout ${RT_TARPIT_TIMEOUT}s
            size 65535
        }

        # SYN Proxy Chain (Handshake Offloading)
        chain rt_synproxy {
            synproxy roughen tcp mss 1460 wscale 80 sack yes timestamp yes accept
        }

        chain input {
            type filter hook input priority -10; policy accept;

            # --- A. PACKET VALIDITY (Sanity Checks) ---
            # Drop invalid packets (out of state, malformed)
            ct state invalid drop
            
            # Drop packets claiming to be related/established but invalid
            ct state established, related accept

            # --- B. Enforce Penalty Box ---
            ip saddr @rt_penalty_box drop

            # --- C. TCP Validity Enforcement ---
            # Drop NEW packets that do not have the SYN flag (e.g. FIN scans, Null scans)
            tcp flags & (fin|syn|rst|ack) != syn ct state new drop
            
            # Drop Bogus TCP Flags (Impossible combinations)
            tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop              # Null packet
            tcp flags & (fin|syn|rst|psh|ack|urg) == (fin|psh|urg) drop # XMAS packet
            tcp flags & (fin|syn) == (fin|syn) drop                      # SYN-FIN

            # --- D. "Revolutionary Tech" Signatures ---
            # Bogus TCP Options (Offset 34 pattern)
            @th,272,16 0x40 drop
            # Malformed IP Header Length
            @nh,96,4 & 0x000F0000 == 0x50000 drop

            # --- E. SYN Flood Mitigation (SYN Proxy) ---
            # Offload Handshakes for Web Ports
            tcp dport { 80, 443 } tcp flags & (fin|syn|rst|ack) == syn jump rt_synproxy

            # --- F. Dynamic Rate Limiting ---
            # If > 50 new SYNs/sec, add to Penalty Box for configured timeout
            tcp flags & (fin|syn|rst|ack) == syn \
                limit rate 50/second burst 100 packets \
                add @rt_penalty_box { ip saddr }

            # --- G. ICMP Flood Protection ---
            icmp type echo-request limit rate 5/second accept
            icmp type echo-request drop
        }
    }
EOF

    # Populate Static Blocks (Optional - usually handled by CSF, but good for redundancy)
    if [ -f "$DENY_PERM" ]; then
        grep -vE "^#|^$" "$DENY_PERM" | awk '{print $1}' | while read IP; do
            $NFT add element inet rt_security rt_penalty_box { $IP timeout 30d } 2>/dev/null
        done
    fi

# ==============================================================================
# 3B. IPTABLES IMPLEMENTATION (Legacy)
# ==============================================================================
else
    echo "[RT-StressEngine] Applying Legacy IPtables Rulesets..."
    
    # Kernel Hardening
    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rfc1337=1 >/dev/null 2>&1

    # Setup Chains
    $IPTABLES -t raw -F RT_STRESS_ENGINE_RAW 2>/dev/null
    $IPTABLES -t raw -X RT_STRESS_ENGINE_RAW 2>/dev/null
    $IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER 2>/dev/null
    $IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER 2>/dev/null

    $IPTABLES -t raw -N RT_STRESS_ENGINE_RAW
    $IPTABLES -t filter -N RT_STRESS_ENGINE_FILTER
    $IPTABLES -t raw -I PREROUTING 1 -j RT_STRESS_ENGINE_RAW
    $IPTABLES -I INPUT 1 -j RT_STRESS_ENGINE_FILTER

    # Create IP Sets
    $IPSET create rt_google_safesites hash:net comment -exist >/dev/null 2>&1
    $IPSET create rt_stress_block hash:ip hashsize 4096 maxelem 200000 timeout $RT_TARPIT_TIMEOUT -exist >/dev/null 2>&1
    $IPSET flush rt_stress_block

    # 1. Allow Google (Bypass Validity Checks to prevent false positives on crawlers)
    $IPTABLES -t raw -I RT_STRESS_ENGINE_RAW 1 -m set --match-set rt_google_safesites src -j ACCEPT

    # 2. Packet Validity (Stateless / Raw)
    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL NONE -j DROP
    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL ALL -j DROP
    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

    # 3. "Revolutionary Tech" Signatures
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP

    # Determine Drop Target (Configured by User)
    DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)
    case "$DROP_SETTING" in
        TARPIT) TARGET_MODULE="TARPIT"; TARGET_OPTS="" ;;
        CHAOS)  TARGET_MODULE="CHAOS"; TARGET_OPTS="--tarpit --delude" ;;
        DELUDE) TARGET_MODULE="DELUDE"; TARGET_OPTS="" ;;
        *)      TARGET_MODULE="DROP"; TARGET_OPTS="" ;;
    esac

    # 4. Apply Blocks (The Punishment)
    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -m set --match-set rt_stress_block src -j NOTRACK
    
    if [ "$TARGET_MODULE" == "DROP" ]; then
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
    else
        # Only TCP can be Tarpitted/Deluded
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -p tcp -j $TARGET_MODULE $TARGET_OPTS
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
    fi
    
    # 5. Rate Limit to Dynamic Set
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m hashlimit \
        --hashlimit-name rt_flood \
        --hashlimit-above 50/sec \
        --hashlimit-burst 100 \
        --hashlimit-mode srcip \
        -j SET --add-set rt_stress_block src --timeout $RT_TARPIT_TIMEOUT
fi

echo "[RT-StressEngine] Status: Active ($MODE)"