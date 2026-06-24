#!/bin/bash
# ==============================================================================
# ConfigServer by Revolutionary Technology - Google Safe Sites Zero Trust Engine
# Description: 24/7 Service to poll Threat Intel feeds and inject them into 
#              kernel-level ipsets for ahead-of-the-threat dropping.
# ==============================================================================

# Configuration
SET_NAME="rt_google_safesites"
SET_TEMP="${SET_NAME}_temp"
POLL_INTERVAL=14400 # 4 Hours (in seconds)
IPTABLES=$(which iptables)
IPSET=$(which ipset)

# Threat Intelligence Feeds (Simulating Google Safe Browsing / Web Risk endpoints)
# In production, replace the primary URL with your Google Web Risk API endpoint
FEEDS=(
    "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
)

echo "[+] Initializing Revolutionary Technology Zero Trust Defense..."

# Ensure ipset is installed
if [ -z "$IPSET" ]; then
    echo "[!] Fatal: ipset is not installed. Please install it."
    exit 1
fi

# 1. Establish the Kernel IPSet and IPTables Hook
setup_kernel_hooks() {
    # Create the permanent set if it doesn't exist (hashsize optimized for high volume)
    $IPSET create $SET_NAME hash:net family inet hashsize 131072 maxelem 2000000 2>/dev/null
    
    # Hook the ipset into the RAW PREROUTING table.
    # This drops the packet BEFORE the Linux kernel tracks the connection, saving RAM and CPU.
    if ! $IPTABLES -t raw -C PREROUTING -m set --match-set $SET_NAME src -j DROP 2>/dev/null; then
        echo "    > Hooking $SET_NAME into L3 RAW PREROUTING boundary..."
        $IPTABLES -t raw -I PREROUTING 1 -m set --match-set $SET_NAME src -j DROP
    fi
}

# 2. Poller & Injector Logic
update_threat_intel() {
    echo "[*] Polling Threat Intelligence Feeds..."
    
    # Create a temporary set for atomic swapping (prevents zero-protection window during updates)
    $IPSET create $SET_TEMP hash:net family inet hashsize 131072 maxelem 2000000 2>/dev/null
    $IPSET flush $SET_TEMP

    # Fetch and parse feeds
    for feed in "${FEEDS[@]}"; do
        echo "    > Fetching $feed..."
        # Extract valid IPv4 subnets/IPs, ignore comments, and inject into temp set
        curl -sL "$feed" | grep -vE "^#|^$" | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$" | while read -r IP; do
            $IPSET add $SET_TEMP "$IP" -exist
        done
    done

    # Count downloaded threats
    THREAT_COUNT=$($IPSET list $SET_TEMP | wc -l)
    let THREAT_COUNT=THREAT_COUNT-8 # Adjust for ipset header lines

    if [ "$THREAT_COUNT" -gt 0 ]; then
        # Atomic Swap: Instantly replace the live set with the newly compiled temp set
        $IPSET swap $SET_TEMP $SET_NAME
        echo "[+] Atomic Swap Complete. Active Zero-Trust Threats Blocked: $THREAT_COUNT"
    else
        echo "[-] Warning: No IPs retrieved. Aborting swap to protect existing blocklist."
    fi

    # Destroy the temporary set
    $IPSET destroy $SET_TEMP
}

# 3. Main 24/7 Daemon Loop
setup_kernel_hooks

while true; do
    update_threat_intel
    echo "[*] Poller sleeping for $POLL_INTERVAL seconds..."
    sleep $POLL_INTERVAL
done
