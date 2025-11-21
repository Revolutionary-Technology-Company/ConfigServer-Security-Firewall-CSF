#!/bin/bash
#
# Certificate Generator for ConfigServer Security & Firewall UI
# Repatriated for Revolutionary Technology
#

KEY="ui/server.key"
CRT="ui/server.crt"
DAYS=3650

# Metadata for the certificate
COUNTRY="US"
STATE="Washington"
CITY="Seattle"
ORG="Revolutionary Technology"
OU="ConfigServer Security & Firewall"
CN="ConfigServer Security & Firewall"
EMAIL="system@configserver.shop"

echo "Generating UI Private Key and Certificate..."
mkdir -p ui

# Generate robust private key and self-signed cert in one pass
openssl req -x509 -nodes -days $DAYS -newkey rsa:4096 \
    -keyout "$KEY" \
    -out "$CRT" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN/emailAddress=$EMAIL" 2>/dev/null

chmod 600 "$KEY"
chmod 600 "$CRT"

echo "[OK] Generated $KEY and $CRT for $CN ($ORG)"