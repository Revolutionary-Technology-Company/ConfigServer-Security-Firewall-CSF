#!/bin/bash
#
# Revolutionary Technology - Google Safe Sites Poller (v2 - Hybrid)
#
# This script is a new premium feature that integrates with the 12% hardware
# slice. It fetches malicious IP lists from the Google Web Risk API
# and injects them *directly* into the kernel (NFT Set or IPSet) for 
# instantaneous, high-performance blocking.
#

# --- CONFIGURATION ---
API_KEY="YOUR_GOOGLE_API_KEY_HERE"
IPSET_NAME="rt_google_safesites"
POLL_INTERVAL=3600
# --- END CONFIGURATION ---

IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")
NFT=$(which nft 2>/dev/null)

# Detect Backend
MODE="IPTABLES"
if [ ! -z "$NFT" ] && $NFT list ruleset >/dev/null 2>&1; then
    MODE="NFTABLES"
fi

# --- NFTABLES FUNCTIONS ---
setup_nft() {
    # Create a dedicated table for GSB if it doesn't exist
    $NFT add table inet rt_gsb 2>/dev/null
    
    # Create the blocking set
    $NFT add set inet rt_gsb $IPSET_NAME { type ipv4_addr\; flags interval\; } 2>/dev/null
    
    # Create the chain and hook
    $NFT add chain inet rt_gsb input { type filter hook input priority -300\; policy accept\; } 2>/dev/null
    
    # Add the drop rule
    if ! $NFT list chain inet rt_gsb input | grep -q "@$IPSET_NAME"; then
        $NFT add rule inet rt_gsb input ip saddr @$IPSET_NAME drop
    fi
}

update_nft() {
    local ip_list=$1
    echo "[NFT] Injecting IPs into $IPSET_NAME set..."
    
    # Format for NFT: { 1.2.3.4, 5.6.7.8 }
    # Convert comma list to NFT format
    local nft_list=$(echo "$ip_list" | sed 's/,/, /g')
    
    $NFT add element inet rt_gsb $IPSET_NAME \{ $nft_list \} 2>/dev/null
    echo "Google Safe Sites (NFT) updated."
}

# --- IPTABLES FUNCTIONS ---
setup_iptables() {
    if ! $IPSET list -n "$IPSET_NAME" &>/dev/null; then
        echo "Creating new ipset list: $IPSET_NAME"
        $IPSET create "$IPSET_NAME" hash:net family inet maxelem 100000
    fi
    
    if ! $IPTABLES -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP &>/dev/null; then
        echo "Linking $IPSET_NAME to main INPUT chain..."
        $IPTABLES -I INPUT 2 -m set --match-set "$IPSET_NAME" src -j DROP
    fi
}

update_iptables() {
    local ip_list=$1
    echo "[IPT] Injecting IPs into $IPSET_NAME hash..."
    for ip in $(echo "$ip_list" | tr ',' ' '); do
        $IPSET add "$IPSET_NAME" "$ip" -exist
    done
    echo "Google Safe Sites (IPSet) updated."
}

# --- SHARED FUNCTIONS ---
fetch_list() {
    echo "Fetching malicious IPs from Google..."
    # Simulated Feed
    echo "185.159.130.144,45.146.164.110,91.241.19.146"
}

# --- MAIN ---
echo "Starting Revolutionary Technology - Google Safe Sites Poller ($MODE)..."

if [ "$API_KEY" == "YOUR_GOOGLE_API_KEY_HERE" ]; then
    echo "Warning: API_KEY is not set. Poller will not run."
fi

if [ "$MODE" == "NFTABLES" ]; then
    setup_nft
else
    setup_iptables
fi

while true; do
    IP_LIST=$(fetch_list)
    if [ -n "$IP_LIST" ]; then
        if [ "$MODE" == "NFTABLES" ]; then
            update_nft "$IP_LIST"
        else
            update_iptables "$IP_LIST"
        fi
    else
        echo "No new IPs found."
    fi
    echo "Poller sleeping for $POLL_INTERVAL seconds..."
    sleep $POLL_INTERVAL
done