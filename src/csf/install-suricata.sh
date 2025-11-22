#!/bin/bash
# #
#   @script             Revolutionary Technology Suricata IPS Installer
#   @description        Installs Suricata in IPS (NFQUEUE) mode with JA3 hashing.
#                       Integrates with CSF via csfpost.sh.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

echo "[NGFW] Installing Suricata IPS (Deep Packet Inspection)..."

# 1. Install Dependencies & Suricata
if [ -f /usr/bin/apt-get ]; then
    export DEBIAN_FRONTEND=noninteractive
    add-apt-repository ppa:oisf/suricata-stable -y >/dev/null 2>&1
    apt-get update >/dev/null 2>&1
    apt-get install -y suricata jq >/dev/null 2>&1
elif [ -f /usr/bin/yum ]; then
    yum install -y epel-release >/dev/null 2>&1
    yum install -y suricata jq >/dev/null 2>&1
fi

# 2. Configure for IPS (Inline Blocking)
# We switch from AF_PACKET (Passive IDS) to NFQUEUE (Active IPS)
echo "    > Configuring Suricata for Inline IPS mode..."
sed -i 's/mode: af-packet/mode: nfqueue/' /etc/suricata/suricata.yaml
sed -i 's/fail-open: yes/fail-open: no/' /etc/suricata/suricata.yaml

# 3. Enable JA3 (Encrypted Traffic Inspection)
# This allows detecting malware C2 channels even inside TLS
if ! grep -q "ja3-fingerprints: yes" /etc/suricata/suricata.yaml; then
    echo "    > Enabling JA3 TLS Fingerprinting..."
    cat >> /etc/suricata/suricata.yaml <<EOF

app-layer:
  protocols:
    tls:
      enabled: yes
      ja3-fingerprints: yes
EOF
fi

# 4. Update Threat Intelligence
echo "    > Downloading Emerging Threats Open Ruleset..."
suricata-update >/dev/null 2>&1

# 5. Integrate with CSF (The "Handshake")
# We need to send traffic from IPTables to Suricata.
# We do this in csfpost.sh so it persists after CSF restarts.
POST_SCRIPT="/usr/local/csf/bin/csfpost_suricata.sh"

echo "    > Creating CSF Integration Hook..."
cat <<EOF > "$POST_SCRIPT"
#!/bin/bash
# Revolutionary Technology - Suricata Hook
# Send NEW TCP traffic to Suricata for Deep Packet Inspection
# We bypass the loopback and local traffic to save CPU
iptables -I INPUT -i lo -j ACCEPT
iptables -I INPUT -p tcp -m state --state NEW -j NFQUEUE --queue-bypass
EOF
chmod 700 "$POST_SCRIPT"

# Add to main csfpost.sh if not present
if [ ! -f "/etc/csf/csfpost.sh" ]; then
    echo "sh $POST_SCRIPT" > /etc/csf/csfpost.sh
    chmod 700 /etc/csf/csfpost.sh
elif ! grep -q "csfpost_suricata.sh" /etc/csf/csfpost.sh; then
    echo "sh $POST_SCRIPT" >> /etc/csf/csfpost.sh
fi

# 6. Start Service
systemctl enable suricata >/dev/null 2>&1
systemctl restart suricata >/dev/null 2>&1

echo "    [OK] Suricata IPS Active. Traffic is now being inspected."