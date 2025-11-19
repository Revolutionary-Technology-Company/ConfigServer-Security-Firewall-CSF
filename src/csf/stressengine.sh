#!/bin/bash
# #
#   @script             Revolutionary Technology Stress Engine (v4.5)
#   @description        Hardware (XDP) & Kernel (Tarpit/Chaos/Delude) defense layer.
#                       Runs before CSF to offload attack traffic.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

echo "[RT-StressEngine] Loading Revolutionary Technology Stress Engine..."

# --- CONFIGURATION ---
CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")
BPF_LOADER="/usr/local/csf/bin/csf-bpf-loader.sh"
RT_TARPIT_TIMEOUT=$(grep "^RT_TARPIT_TIMEOUT" "$CSF_CONF" | cut -d'"' -f2)
: "${RT_TARPIT_TIMEOUT:=600}"

# ==============================================================================
# 1. HARDWARE OFFLOADING (XDP/BPF)
# ==============================================================================
if [ -f "$BPF_LOADER" ] && [ -x "$BPF_LOADER" ]; then
    echo "[RT-StressEngine] Loading XDP/BPF hardware filters..."
    $BPF_LOADER
else
    echo "[RT-StressEngine] BPF loader not found. Falling back to standard iptables."
fi

# ==============================================================================
# 2. CHAIN & IPSET SETUP
# ==============================================================================
# Flush old custom chains to start clean
$IPTABLES -t raw -F RT_STRESS_ENGINE_RAW 2>/dev/null
$IPTABLES -t raw -X RT_STRESS_ENGINE_RAW 2>/dev/null
$IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER 2>/dev/null
$IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER 2>/dev/null

# Create new chains
$IPTABLES -t raw -N RT_STRESS_ENGINE_RAW
$IPTABLES -t filter -N RT_STRESS_ENGINE_FILTER

# Hook chains
# RAW: For stateless matching (NOTRACK)
$IPTABLES -t raw -I PREROUTING 1 -j RT_STRESS_ENGINE_RAW
# FILTER: For applying the final Target
$IPTABLES -I INPUT 1 -j RT_STRESS_ENGINE_FILTER

# Create IP Sets
# 1. Google Whitelist
$IPSET create rt_google_safesites hash:net comment -exist >/dev/null 2>&1
# 2. Penalty Box (The Block List)
$IPSET create rt_stress_block hash:ip hashsize 4096 maxelem 200000 -exist >/dev/null 2>&1
$IPSET flush rt_stress_block

# ==============================================================================
# 3. GOOGLE SAFE SITES (Priority Whitelist)
# ==============================================================================
# Allow Google IPs immediately in RAW table to bypass all tracking and limits
$IPTABLES -t raw -I RT_STRESS_ENGINE_RAW 1 -m set --match-set rt_google_safesites src -j ACCEPT

# ==============================================================================
# 4. DETERMINE STRESS TARGET
# ==============================================================================
# Read the DROP setting from csf.conf
DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)

case "$DROP_SETTING" in
    TARPIT)
        TARGET_MODULE="TARPIT"
        TARGET_OPTS="" 
        ;;
    CHAOS)
        TARGET_MODULE="CHAOS"
        TARGET_OPTS="--tarpit --delude" 
        ;;
    DELUDE)
        TARGET_MODULE="DELUDE"
        TARGET_OPTS=""
        ;;
    *)
        TARGET_MODULE="DROP"
        TARGET_OPTS=""
        ;;
esac
echo "[RT-StressEngine] Strategy Selected: $TARGET_MODULE"

# ==============================================================================
# 5. PATTERN-BASED DEFENSE (Signatures)
# ==============================================================================
# Drop Invalid Packets (Stateless / Raw)
$IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL NONE -j DROP
$IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --tcp-flags ALL ALL -j DROP

# SYN Flood Hex Signatures (Common botnet tools)
$IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP
$IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP

# Payload-on-SYN (Tarpit/Drop specific signature)
if [ "$TARGET_MODULE" == "DROP" ]; then
     $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -p tcp --syn -m length --length 100:65535 -j DROP
else
     # If we are using advanced modules, handle this in FILTER table with the module
     $IPTABLES -A RT_STRESS_ENGINE_FILTER -p tcp --syn -m length --length 100:65535 -j $TARGET_MODULE $TARGET_OPTS
fi

# ==============================================================================
# 6. IP-BASED DEFENSE (Populate & Punish)
# ==============================================================================
echo "[RT-StressEngine] Populating block lists into IPSet..."

# Populate from Permanent Deny
if [ -f "$DENY_PERM" ]; then
    grep -vE "^#|^$" "$DENY_PERM" | awk '{print $1}' | while read IP; do
        $IPSET -A rt_stress_block "$IP" -exist
    done
fi

# Populate from Temporary Ban
if [ -f "$DENY_TEMP" ]; then
    grep -vE "^#|^$" "$DENY_TEMP" | cut -d'|' -f1 | while read IP; do
        $IPSET -A rt_stress_block "$IP" -exist
    done
fi

# --- APPLY THE PUNISHMENT ---

# 1. RAW Table: Match the IPSet and NOTRACK it
# Prevents conntrack table exhaustion
$IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -m set --match-set rt_stress_block src -j NOTRACK

# 2. FILTER Table: Match the UNTRACKED state + IPSet and apply TARGET
if [ "$TARGET_MODULE" == "DROP" ]; then
    # Simple DROP
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
else
    # Advanced Xtables Target (TCP only)
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -p tcp -j $TARGET_MODULE $TARGET_OPTS
    
    # Fallback for UDP/ICMP (Drop them, they can't be tarpitted)
    $IPTABLES -A RT_STRESS_ENGINE_FILTER -m set --match-set rt_stress_block src -j DROP
fi

# 3. Safety Net: Drop any leaked UNTRACKED packets
$IPTABLES -A RT_STRESS_ENGINE_FILTER -m conntrack --ctstate UNTRACKED -j DROP

echo "[RT-StressEngine] Active."