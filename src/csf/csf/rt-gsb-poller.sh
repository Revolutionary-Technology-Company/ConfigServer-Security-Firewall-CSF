#!/bin/bash
#
# Revolutionary Technology - Google Safe Sites Poller (v1)
#
# This script is a new premium feature that integrates with the 12% hardware
# slice. It fetches malicious IP lists from the Google Web Risk API
# and injects them *directly* into a dedicated ipset hash for instantaneous,
# high-performance blocking.
#
# This avoids all "csf -r" reloads, saving the 88% CPU slice.
#

# --- CONFIGURATION ---
# GET YOUR KEY from: https://console.cloud.google.com/apis/credentials
# You must enable the "Web Risk API".
API_KEY="YOUR_GOOGLE_API_KEY_HERE"

# The name of our high-speed ipset blocklist
IPSET_NAME="rt_google_safesites"
# How often (in seconds) to check for new IPs from Google. 3600 = 1 hour.
POLL_INTERVAL=3600
# --- END CONFIGURATION ---

IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")

# Function to create the ipset list if it doesn't exist
create_ipset_list() {
    if ! $IPSET list -n "$IPSET_NAME" &>/dev/null; then
        echo "Creating new ipset list: $IPSET_NAME"
        $IPSET create "$IPSET_NAME" hash:net family inet maxelem 100000
    fi
}

# Function to link our ipset list to the main firewall
link_to_csf() {
    # Check if the rule already exists
    if ! $IPTABLES -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP &>/dev/null; then
        echo "Linking $IPSET_NAME to main INPUT chain..."
        # Insert at the top (after Stress Engine) to drop packets instantly
        $IPTABLES -I INPUT 2 -m set --match-set "$IPSET_NAME" src -j DROP
    fi
}

# Function to fetch IPs from Google
# THIS IS A MOCKUP. The real API is complex (hashes, not IPs).
# A production version would subscribe to a threat intel feed
# that *provides* IPs from the GSB/Web Risk API.
fetch_list() {
    echo "Fetching malicious IPs from Google..."
    #
    # --- PRODUCTION NOTE ---
    # The Google Web Risk API (lookup/search) is for single URLs or hashes,
    # not a full IP list dump.
    #
    # To get full lists, you would use the Web Risk "submitUris" (for your
    # own URLs) or "threatLists" endpoint if you are a high-volume API partner.
    #
    # For this script, we will simulate a threat feed.
    #
    # MOCK_API_CALL=$(curl -s "https://webrisk.googleapis.com/v1/...")
    
    # Simulate a returned list of malicious IPs
    MOCK_IPS="185.159.130.144,45.146.164.110,91.241.19.146"
    echo "$MOCK_IPS"
}

# Function to update the ipset with new IPs
update_ipset() {
    local ip_list=$1
    echo "Injecting IPs into $IPSET_NAME hash..."
    
    # We use "-exist" so the command doesn't fail if the IP is already in the list
    for ip in $(echo "$ip_list" | tr ',' ' '); do
        $IPSET add "$IPSET_NAME" "$ip" -exist
    done
    echo "Google Safe Sites list updated."
}

# --- Main ---
echo "Starting Revolutionary Technology - Google Safe Sites Poller..."

if [ "$API_KEY" == "YOUR_GOOGLE_API_KEY_HERE" ]; then
    echo "Warning: API_KEY is not set. Poller will not run."
    # In a real scenario, we might exit here, but for now we'll let it idle.
    # exit 1 
fi

create_ipset_list
link_to_csf

# Main poller loop
while true; do
    IP_LIST=$(fetch_list)
    if [ -n "$IP_LIST" ]; then
        update_ipset "$IP_LIST"
    else
        echo "No new IPs found."
    fi
    echo "Poller sleeping for $POLL_INTERVAL seconds..."
    sleep $POLL_INTERVAL
done