#!/bin/sh
#
# Revolutionary Technology - Attacker Stress Engine (v3)
#
# This script CHECKS if the user has enabled TARPIT in csf.conf.
# If (and only if) DROP = "TARPIT", this script will
# upgrade the action to use the high-performance, stateless xt_TARPIT module.
#

echo "Loading Attacker Stress Engine (Stateless TARPIT)..."

# --- CONFIGURATION ---
CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
IPTABLES=$(which iptables)
if [ -z "$IPTABLES" ]; then
    IPTABLES="/sbin/iptables"
fi

# --- 1. CHECK if TARPIT is enabled in csf.conf ---
DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)

if [ "$DROP_SETTING" != "TARPIT" ]; then
    echo "Attacker Stress Engine is IDLE (DROP != TARPIT in csf.conf). Exiting."
    
    # Flush any old rules from our chains just in case
    $IPTABLES -t raw -F RT_TARPIT_RAW > /dev/null 2>&1
    $IPTABLES -t raw -X RT_TARPIT_RAW > /dev/null 2>&1
    $IPTABLES -t filter -F RT_TARPIT_FILTER > /dev/null 2>&1
    $IPTABLES -t filter -X RT_TARPIT_FILTER > /dev/null 2>&1
    exit 0
fi

echo "TARPIT setting detected. Upgrading to high-performance stateless module."

# --- 2. Flush old rules ---
$IPTABLES -t raw -F RT_TARPIT_RAW > /dev/null 2>&1
$IPTABLES -t raw -X RT_TARPIT_RAW > /dev/null 2>&1
$IPTABLES -t filter -F RT_TARPIT_FILTER > /dev/null 2>&1
$IPTABLES -t filter -X RT_TARPIT_FILTER > /dev/null 2>&1

# --- 3. Create our new chains ---
$IPTABLES -t raw -N RT_TARPIT_RAW
$IPTABLES -t filter -N RT_TARPIT_FILTER

# --- 4. Link main chains to our custom chains ---
$IPTABLES -t raw -A PREROUTING -j RT_TARPIT_RAW
$IPTABLES -I INPUT 1 -j RT_TARPIT_FILTER

# --- 5. Populate our chains from CSF's block lists ---

# Process Permanent Deny List
if [ -f "$DENY_PERM" ]; then
    grep -vE "^#|^$" "$DENY_PERM" | while read -r IP; do
        $IPTABLES -t raw -A RT_TARPIT_RAW -s "$IP" -j NOTRACK
        $IPTABLES -A RT_TARPIT_FILTER -s "$IP" -m conntrack --ctstate UNTRACKED -j TARPIT
    done
fi

# Process Temporary Ban List
if [ -f "$DENY_TEMP" ]; then
    grep -vE "^#|^$" "$DENY_TEMP" | cut -d'|' -f1 | while read -r IP; do
        $IPTABLES -t raw -A RT_TARPIT_RAW -s "$IP" -j NOTRACK
        $IPTABLES -A RT_TARPIT_FILTER -s "$IP" -m conntrack --ctstate UNTRACKED -j TARPIT
    done
fi

# --- 6. Finalize chains ---
$IPTABLES -A RT_TARPIT_FILTER -m conntrack --ctstate UNTRACKED -j DROP

echo "Attacker Stress Engine (Stateless TARPIT) rules loaded."