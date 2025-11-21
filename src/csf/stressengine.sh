#!/bin/sh
#
# Revolutionary Technology - Attacker Stress Engine (v4.1)
#
# This script is now a dynamic target selector. It reads the DROP setting
# from csf.conf and applies the corresponding, high-performance, stateless
# xtables-addons module (TARPIT, CHAOS, or DELUDE) to all blocked IPs.
#
# This ensures all xtables-addons are equally optimized.
#

echo "Loading Attacker Stress Engine (Dynamic Target)..."

# --- CONFIGURATION ---
CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
IPTABLES=$(which iptables)
if [ -z "$IPTABLES" ]; then
    IPTABLES="/sbin/iptables"
fi

# --- 1. CHECK which Stress Target is enabled in csf.conf ---
DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)
TARGET=""

case "$DROP_SETTING" in
    TARPIT)
        echo "TARPIT target detected. (Slows scanners)"
        TARGET="TARPIT"
        ;;
    CHAOS)
        echo "CHAOS target detected. (Confuses scanners)"
        TARGET="CHAOS"
        ;;
    DELUDE)
        echo "DELUDE target detected. (Fools scanners)"
        TARGET="DELUDE"
        ;;
    *)
        echo "Attacker Stress Engine is IDLE (DROP is not TARPIT, CHAOS, or DELUDE). Exiting."
        
        # Flush any old rules from our chains just in case
        $IPTABLES -t raw -F RT_STRESS_ENGINE_RAW > /dev/null 2>&1
        $IPTABLES -t raw -X RT_STRESS_ENGINE_RAW > /dev/null 2>&1
        $IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER > /dev/null 2>&1
        $IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER > /dev/null 2>&1
        exit 0
        ;;
esac

echo "Upgrading all blocks to high-performance stateless module: $TARGET"

# --- 2. Flush old rules ---
$IPTABLES -t raw -F RT_STRESS_ENGINE_RAW > /dev/null 2>&1
$IPTABLES -t raw -X RT_STRESS_ENGINE_RAW > /dev/null 2>&1
$IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER > /dev/null 2>&1
$IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER > /dev/null 2>&1

# --- 3. Create our new chains ---
$IPTABLES -t raw -N RT_STRESS_ENGINE_RAW
$IPTABLES -t filter -N RT_STRESS_ENGINE_FILTER

# --- 4. Link main chains to our custom chains ---
# We must hook into PREROUTING *before* nf_conntrack sees the packet
$IPTABLES -t raw -A PREROUTING -j RT_STRESS_ENGINE_RAW
$IPTABLES -I INPUT 1 -j RT_STRESS_ENGINE_FILTER

# --- 5. Populate our chains from CSF's block lists ---

# Process Permanent Deny List
if [ -f "$DENY_PERM" ]; then
    grep -vE "^#|^$" "$DENY_PERM" | while read -r IP; do
        # 1. In RAW, mark the packet to bypass connection tracking
        $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -s "$IP" -j NOTRACK
        # 2. In FILTER, apply the dynamic TARGET to the untracked packet
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -s "$IP" -m conntrack --ctstate UNTRACKED -j $TARGET
    done
fi

# Process Temporary Ban List
if [ -f "$DENY_TEMP" ]; then
    grep -vE "^#|^$" "$DENY_TEMP" | cut -d'|' -f1 | while read -r IP; do
        # 1. In RAW, mark the packet to bypass connection tracking
        $IPTABLES -t raw -A RT_STRESS_ENGINE_RAW -s "$IP" -j NOTRACK
        # 2. In FILTER, apply the dynamic TARGET to the untracked packet
        $IPTABLES -A RT_STRESS_ENGINE_FILTER -s "$IP" -m conntrack --ctstate UNTRACKED -j $TARGET
    done
fi

# --- 6. Finalize the chains ---
# Any packet that was set to NOTRACK but didn't match an IP
# must be dropped to prevent it from bypassing conntrack.
$IPTABLES -A RT_STRESS_ENGINE_FILTER -m conntrack --ctstate UNTRACKED -j DROP

echo "Attacker Stress Engine ($TARGET) rules loaded."