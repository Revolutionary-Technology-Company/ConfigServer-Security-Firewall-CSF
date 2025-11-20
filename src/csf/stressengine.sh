#!/bin/bash
# #
#   @script             Revolutionary Technology Stress Engine (v5.3 - Tuned)
#   @description        Hybrid Driver (XDP) + Kernel (NFT/IPT) Defense Layer.
#                       Respects Auto-Tuner resource limits from csf.conf.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

echo "[RT-StressEngine] Loading Revolutionary Technology Stress Engine..."

# --- CONFIGURATION & TOOLS ---
CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
BPF_LOADER="/usr/local/csf/bin/csf-bpf-loader.sh"

NFT=$(which nft 2>/dev/null)
IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")

# --- READ AUTO-TUNED VALUES ---
# We must respect the 12% resource slice calculated by the installer.

# 1. Tarpit Timeout
RT_TARPIT_TIMEOUT=$(grep "^RT_TARPIT_TIMEOUT" "$CSF_CONF" | cut -d'"' -f2)
: "${RT_TARPIT_TIMEOUT:=600}"

# 2. IPSet / Table Size (Tuned by RAM)
LF_IPSET_MAXELEM=$(grep "^LF_IPSET_MAXELEM" "$CSF_CONF" | cut -d'"' -f2)
: "${LF_IPSET_MAXELEM:=65535}"

# 3. Rate Limits (Tuned by CPU Cores)
SYNFLOOD_RATE=$(grep "^SYNFLOOD_RATE" "$CSF_CONF" | cut -d'"' -f2)
: "${SYNFLOOD_RATE:=100/s}"
# NFTables prefers "100/second" but accepts "100/s". We normalize just in case.
SYNFLOOD_RATE_NFT=$(echo "$SYNFLOOD_RATE" | sed 's/\/s/\/second/')

SYNFLOOD_BURST=$(grep "^SYNFLOOD_BURST" "$CSF_CONF" | cut -d'"' -f2)
: "${SYNFLOOD_BURST:=150}"

echo "[RT-StressEngine] Configuration Loaded:"
echo "    - Timeout: ${RT_TARPIT_TIMEOUT}s"
echo "    - Max Elements: ${LF_IPSET_MAXELEM}"
echo "    - Rate Limit: ${SYNFLOOD_RATE} (Burst: ${SYNFLOOD_BURST})"

# ==============================================================================
# 1. HARDWARE OFFLOADING (XDP/BPF) - Layer 0
# ==============================================================================
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

    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rfc1337=1 >/dev/null 2>&1

    $NFT -f - <<EOF
    table inet rt_security {
        # Dynamic Penalty Box (Respects Tuned Size)
        set rt_penalty_box {
            type ipv4_addr
            flags dynamic, timeout
            timeout ${RT_TARPIT_TIMEOUT}s
            size ${LF_IPSET_MAXELEM}
        }

        chain rt_synproxy {
            synproxy mss 1460 wscale 80 sack yes timestamp yes accept
        }

        chain input {
		# Priority -400 places us BEFORE Connection Tracking (Raw Table equivalent).
		# This is crucial for a "Stress Engine" to prevent state-table exhaustion.
		type filter hook input priority -400; policy accept;

            ct state invalid drop
            ct state established, related accept

            # Enforce Penalty Box
            ip saddr @rt_penalty_box drop

            # Validity Checks
            tcp flags & (fin|syn|rst|ack) != syn ct state new drop
            tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop
            tcp flags & (fin|syn|rst|psh|ack|urg) == (fin|psh|urg) drop
            
            # Signatures
            #@th,272,16 0x40 drop
            #@nh,96,4 & 0x000F0000 == 0x50000 drop
			ip version 4 ip ihl != 5 drop
			meta l4proto { tcp, udp } payload @th, 272, 16 u16 == 0x40 drop

            # SYN Proxy
            tcp dport { 80, 443 } tcp flags & (fin|syn|rst|ack) == syn jump rt_synproxy

            # Dynamic Rate Limiting (Respects Tuned Rate/Burst)
            tcp flags & (fin|syn|rst|ack) == syn \
                limit rate ${SYNFLOOD_RATE_NFT} burst ${SYNFLOOD_BURST} packets \
                add @rt_penalty_box { ip saddr }

            icmp type echo-request limit rate 5/second accept
            icmp type echo-request drop
        }
    }
EOF

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
    
    sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rfc1337=1 >/dev/null 2>&1

    $IPTABLES -t raw -F RT_STRESS_ENGINE_RAW 2>/dev/null
    $IPTABLES -t raw -X RT_STRESS_ENGINE_RAW 2>/dev/null
    $IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER 2>/dev/null
    $IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER 2>/dev/null

    $IPTABLES -t raw -N RT_STRESS_ENGINE_RAW
    $IPTABLES -t filter -N RT_STRESS_ENGINE_FILTER
    $IPTABLES -t raw -I PREROUTING 1 -j RT_STRESS_ENGINE_RAW
    $IPTABLES -I INPUT 1 -j RT_STRESS_ENGINE_FILTER

    # Create IP Sets using Tuned Max Elements
    $IPSET create rt_google_safesites hash:net comment -exist >/dev/null 2>&1
    $IPSET create rt_stress_block hash:ip hashsize 4096 maxelem ${LF_IPSET_MAXELEM} timeout $RT_TARPIT_TIMEOUT -exist >/dev/null 2>&1
    $IPSET flush rt_stress_block

    $IPTABLES -t raw -I RT_STRESS_ENGINE_RAW 1 -m set --match-set rt_google_safesites src -j ACCEPT

    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL NONE -j DROP
    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL ALL -j DROP
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP

    DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)
    case "$DROP_SETTING" in
        TARPIT) TARGET_MODULE="TARPIT"; TARGET_OPTS="" ;;
        CHAOS)  TARGET_MODULE="CHAOS"; TARGET_OPTS="--tarpit --delude" ;;
        DELUDE) TARGET_MODULE="DELUDE"; TARGET_OPTS="" ;;
        *)      TARGET_MODULE="DROP"; TARGET_OPTS="" ;;
    esac

    $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -m set --match-set rt_stress_block src -j NOTRACK
    
    if [ "$TARGET_MODULE" == "DROP" ]; then
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
    else
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -p tcp -j $TARGET_MODULE $TARGET_OPTS
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
    fi
    
    # Rate Limit using Tuned Values
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m hashlimit \
        --hashlimit-name rt_flood \
        --hashlimit-above ${SYNFLOOD_RATE} \
        --hashlimit-burst ${SYNFLOOD_BURST} \
        --hashlimit-mode srcip \
        -j SET --add-set rt_stress_block src --timeout $RT_TARPIT_TIMEOUT
fi

echo "[RT-StressEngine] Status: Active ($MODE)"