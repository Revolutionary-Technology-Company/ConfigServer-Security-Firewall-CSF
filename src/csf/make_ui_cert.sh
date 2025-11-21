#!/bin/bash
#
# Certificate Generator for ConfigServer Security & Firewall UI
# Repatriated for Revolutionary Technology
# Smart-bit generation: 16384 for High Perf, 4096 for Standard
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

# Hardware Detection
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')

# Decision Matrix
# Matches "Max Performance" profile from Auto-Tuner (> 8 Cores AND > 16GB RAM)
if [ "$CPU_CORES" -gt 8 ] && [ "$RAM_MB" -gt 16384 ]; then
    BITS=16384
    echo "    > High-Performance Hardware Detected."
    echo "    > Engaging Stunt Mode: Generating 16384-bit keys (Titanium Grade)..."
else
    BITS=4096
    echo "    > Standard Hardware Detected."
    echo "    > Engaging Standard Mode: Generating 4096-bit keys (Military Grade)..."
fi

mkdir -p ui

# Generate private key and self-signed cert
# Redirect stderr to /dev/null to keep the install screen clean, unless it fails
openssl req -x509 -nodes -days $DAYS -newkey rsa:$BITS \
    -keyout "$KEY" \
    -out "$CRT" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN/emailAddress=$EMAIL" 2>/dev/null

if [ -f "$KEY" ]; then
    chmod 600 "$KEY"
    chmod 600 "$CRT"
    echo "    [OK] Keys generated successfully ($BITS-bit)."
else
    echo "    [ERROR] Key generation failed."
fi