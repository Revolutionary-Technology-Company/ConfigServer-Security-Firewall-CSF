#!/usr/bin/env bash
# ==============================================================================
# ConfigServer by Revolutionary Technology - Advanced u32 & SYN Engine
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (sudo)." >&2
  exit 1
fi

INTERFACE="${1:-eth0}"
echo "Applying RT Kernel Hardening and u32 filters to interface: $INTERFACE..."

# --- 1. KERNEL PARAMS: SYN Cookies & Network Hardening ---
# Hardening the TCP/IP stack against state-exhaustion attacks
sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null
sysctl -w net.ipv4.tcp_tw_reuse=1 > /dev/null
sysctl -w net.ipv4.tcp_fin_timeout=15 > /dev/null
sysctl -w net.ipv4.tcp_max_syn_backlog=65535 > /dev/null
sysctl -w net.ipv4.tcp_synack_retries=2 > /dev/null

# --- 2. MALFORMED PACKETS & ANTI-SPOOFING (u32 Layer 3) ---
# Drop packets with an invalid IP header length (shorter than standard headers)
iptables -t mangle -A PREROUTING -i "$INTERFACE" -m u32 --u32 "0 & 0x0F000000 < 0x50000000" -j DROP
# Drop forged local IPs (10.0.0.0/8) originating from the public internet interface
iptables -A INPUT -i "$INTERFACE" -m u32 --u32 "0 & 0xFF000000 = 0x0A000000" -j DROP

# --- 3. REFLECTION FLOODS (u32 Layer 7/UDP) ---
# Block NTP amplification attacks matching payload hex '2a' (MON_GETLIST)
iptables -t mangle -A PREROUTING -i "$INTERFACE" -p udp --dport 123 -m u32 --u32 "0 >> 22 & 0x3C @ 8 = 0x2A000000" -j DROP

# --- 4. TCP STATE & FLAG MITIGATION (Layer 4) ---
# Drop packets establishing a NEW connection that are missing the SYN flag
iptables -t mangle -A PREROUTING -i "$INTERFACE" -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
# Drop Null Flag Attacks (all TCP flags set to 0)
iptables -A INPUT -i "$INTERFACE" -p tcp --tcp-flags ALL NONE -j DROP
# Drop XMAS Flag Attacks (FIN/PSH/URG flags set to 1)
iptables -A INPUT -i "$INTERFACE" -p tcp --tcp-flags ALL ALL -j DROP

# --- 5. GLOBAL RATE LIMITING ---
# Rate limit incoming SYN packets per source IP to prevent SYN exhaustion
iptables -A INPUT -i "$INTERFACE" -p tcp --syn -m hashlimit --hashlimit-name syn_limit \
    --hashlimit-mode srcip --hashlimit-srcmask 32 --hashlimit-above 50/sec --hashlimit-burst 100 -j DROP

echo "Mitigation rules successfully injected into the firewall structure."
