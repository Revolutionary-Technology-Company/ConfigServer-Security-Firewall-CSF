#!/bin/bash
#
# Revolutionary Technology - Block Reporter (v2)
#
# This script runs as a cron job to report malicious domains
# (discovered via rDNS from blocked IPs) to the Google Web Risk API
# as a community defense contribution.
#

# --- CONFIGURATION ---
# GET YOUR KEY from: https://console.cloud.google.com/apis/credentials
# You must enable the "Web Risk API".
API_KEY="YOUR_GOOGLE_API_KEY_HERE"
WEBRISK_URL="https://webrisk.googleapis.com/v1/projects/YOUR-PROJECT-ID/uris:submit"
# ^^^ IMPORTANT: Replace YOUR-PROJECT-ID with your Google Cloud project ID.

DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
STATE_FILE="/var/lib/csf/rt-reporter.state" # Remembers what we've reported
# --- END CONFIGURATION ---

if [ "$API_KEY" == "YOUR_GOOGLE_API_KEY_HERE" ]; then
    echo "Block Reporter is disabled: API_KEY is not set."
    exit 0
fi

if [[ "$WEBRISK_URL" == *"YOUR-PROJECT-ID"* ]]; then
    echo "Block Reporter is disabled: YOUR-PROJECT-ID is not set in WEBRISK_URL."
    exit 0
fi

touch "$STATE_FILE"

# 1. Get all unique IPs from both permanent and temporary deny files
# We only want IPs (CIDR blocks are not useful for this)
ALL_BLOCKED_IPS=$( (cat "$DENY_PERM"; cat "$DENY_TEMP" | cut -d'|' -f1) | \
                    grep -vE "^#|^$" | \
                    grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" | \
                    sort -u )

if [ -z "$ALL_BLOCKED_IPS" ]; then
    echo "No IPs to report."
    exit 0
fi

echo "Found $(echo "$ALL_BLOCKED_IPS" | wc -l) unique IPs to process..."

# 2. Process each IP
for IP in $ALL_BLOCKED_IPS; do
    # Check if we've already reported this IP in the state file
    if grep -q "^$IP$" "$STATE_FILE"; then
        continue
    fi

    # 3. Find the domain name (reverse DNS)
    # We use +short for a clean answer. This is the slowest part.
    DOMAIN=$(host -W 2 "$IP" | awk 'NF==1{print $1}' | sed 's/\.$//' | tail -n 1)

    if [ -z "$DOMAIN" ]; then
        echo "No rDNS found for $IP. Skipping."
        # Mark as processed so we don't check again
        echo "$IP" >> "$STATE_FILE"
        continue
    fi
    
    # We only want to report root domains, not subdomains
    ROOT_DOMAIN=$(echo "$DOMAIN" | rev | cut -d'.' -f1,2 | rev)
    REPORT_URI="http://$ROOT_DOMAIN/" # Google needs a full URI

    # 4. Check if we've already reported this *domain*
    if grep -q "^$ROOT_DOMAIN$" "$STATE_FILE"; then
        echo "Already reported domain $ROOT_DOMAIN (from $IP). Skipping."
        echo "$IP" >> "$STATE_FILE" # Mark IP as processed
        continue
    fi

    echo "Reporting $IP -> $ROOT_DOMAIN to Google..."

    # 5. Build the JSON payload and submit to Google
    # [FIX] Updated threatTypes as requested.
    JSON_PAYLOAD=$(cat <<EOF
{
  "submission": {
    "uri": "$REPORT_URI",
    "threatTypes": [
      "MALWARE",
      "SOCIAL_ENGINEERING"
    ]
  }
}
EOF
)

    # Use curl to send the submission
    curl -s -X POST "$WEBRISK_URL?key=$API_KEY" \
         -H "Content-Type: application/json" \
         -d "$JSON_PAYLOAD" > /dev/null

    # 6. Mark IP and Domain as processed
    echo "$IP" >> "$STATE_FILE"
    echo "$ROOT_DOMAIN" >> "$STATE_FILE"
    
    # Don't hammer the API.
    sleep 1
done

echo "Block reporting complete."