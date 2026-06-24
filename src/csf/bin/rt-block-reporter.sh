#!/bin/bash
# ==============================================================================
# ConfigServer by Revolutionary Technology - Community Defense Reporter (v2)
# Description: Hourly cron intelligence poller that automatically pushes malicious 
#              infrastructure domains to the Google Web Risk API layer[cite: 24, 34].
# ==============================================================================

# --- Configuration ---
# Generate your personal security access token via: https://console.cloud.google.com/apis/credentials
# Ensure the "Web Risk API" service plan is explicitly enabled on your account profile[cite: 24, 34].
API_KEY="YOUR_GOOGLE_API_KEY_HERE"
WEBRISK_URL="https://webrisk.googleapis.com/v1/projects/YOUR-PROJECT-ID/uris:submit"

DENY_PERM="/etc/csf/csf.deny"
DENY_TEMP="/var/lib/csf/csf.tempban"
STATE_FILE="/var/lib/csf/rt-reporter.state" 
# --- End Configuration ---

if [ "$API_KEY" == "YOUR_GOOGLE_API_KEY_HERE" ] || [[ "$WEBRISK_URL" == *"YOUR-PROJECT-ID"* ]]; then
    echo "[*] Community Defense Reporter is idle: API credentials or Project ID unconfigured."
    exit 0
fi

touch "$STATE_FILE"

# 1. Collate unique IPv4 records from permanent and temporary drop tracks[cite: 24, 34]
ALL_BLOCKED_IPS=$( (cat "$DENY_PERM"; cat "$DENY_TEMP" | cut -d'|' -f1) | \
                    grep -vE "^#|^$" | \
                    grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" | \
                    sort -u )

if [ -z "$ALL_BLOCKED_IPS" ]; then
    echo "[-] No active target blocks found to process."
    exit 0
fi

# 2. Iterate through collected threat footprints[cite: 24, 34]
for IP in $ALL_BLOCKED_IPS; do
    if grep -q "^$IP$" "$STATE_FILE"; then
        continue
    fi

    # 3. Transmit lookup request to discover parent infrastructure domain[cite: 24, 34]
    DOMAIN=$(host -W 2 "$IP" | awk 'NF==1{print $1}' | sed 's/\.$//' | tail -n 1)

    if [ -z "$DOMAIN" ]; then
        echo "$IP" >> "$STATE_FILE"
        continue
    fi
    
    # Isolate root domain structure from sub-elements
    ROOT_DOMAIN=$(echo "$DOMAIN" | rev | cut -d'.' -f1,2 | rev)
    REPORT_URI="http://$ROOT_DOMAIN/" 

    if grep -q "^$ROOT_DOMAIN$" "$STATE_FILE"; then
        echo "$IP" >> "$STATE_FILE" 
        continue
    fi

    echo "[+] Reporting malicious asset $IP ($ROOT_DOMAIN) to Google Ecosystem..."

    # 4. Construct threat submission telemetry payload[cite: 24, 34]
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

    # 5. Broadcast to the Web Risk ingestion server[cite: 24, 34]
    curl -s -X POST "$WEBRISK_URL?key=$API_KEY" \
         -H "Content-Type: application/json" \
         -d "$JSON_PAYLOAD" > /dev/null

    # Commit processed state flags to prevent duplicate transmission loops
    echo "$IP" >> "$STATE_FILE"
    echo "$ROOT_DOMAIN" >> "$STATE_FILE"
    
    sleep 1
done

echo "[+] Community block reporting cycle complete."
