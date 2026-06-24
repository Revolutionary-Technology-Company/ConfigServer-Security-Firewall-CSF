#!/bin/bash
#
# ConfigServer by Revolutionary Technology - BPF/XDP Shield Loader
# Description: Compiles BPF source, attaches to NIC, and provisions Maps.
#

CSF_CONF="/etc/csf/csf.conf"
DENY_PERM="/etc/csf/csf.deny"
BPF_SRC="/etc/csf/xdp/csf_xdp_drop.c"
BPF_OBJ="/etc/csf/xdp/csf_xdp_drop.o"

IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    echo "[!] Error: Could not detect primary network interface."
    exit 1
fi

echo "[+] Initializing Revolutionary Technology XDP Engine on $IFACE..."

# 1. bpfilter build system: Compile the eBPF object
echo "    > Compiling BPF program via clang..."
clang -O2 -g -Wall -target bpf -c "$BPF_SRC" -o "$BPF_OBJ"
if [ $? -ne 0 ]; then
    echo "[!] Fatal: BPF compilation failed."
    exit 1
fi

# 2. Unload existing XDP and Attach new object
ip link set dev "$IFACE" xdp off >/dev/null 2>&1
ip link set dev "$IFACE" xdp obj "$BPF_OBJ" sec xdp_shield

if [ $? -ne 0 ]; then
    echo "[!] Fatal: Failed to attach XDP program to $IFACE."
    exit 1
fi

echo "    > XDP program attached successfully."

# 3. Mount BPF filesystem and pin maps for userspace interaction
mount -t bpf bpf /sys/fs/bpf/ 2>/dev/null
BLOCKED_MAP=$(bpftool map show | grep blocked_ips | awk '{print $1}' | tr -d ':')
TCP_MAP=$(bpftool map show | grep tcp_whitelist | awk '{print $1}' | tr -d ':')
UDP_MAP=$(bpftool map show | grep udp_whitelist | awk '{print $1}' | tr -d ':')
STRICT_MAP=$(bpftool map show | grep strict_modes | awk '{print $1}' | tr -d ':')

# Helper: Convert IP to Little Endian Hex for BPF Map Injection
ip_to_hex() {
    printf "%02x %02x %02x %02x" $(echo $1 | tr '.' ' ')
}

# Helper: Convert Port to Little Endian Hex
port_to_hex() {
    printf "%02x %02x" $(($1 & 255)) $(($1 >> 8))
}

# 4. Populate Whitelists (TCP/UDP)
TCP_PORTS=$(grep "^TCP_IN\s*=" "$CSF_CONF" | cut -d'"' -f2 | tr ',' ' ')
for port in $TCP_PORTS; do
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        HEX_PORT=$(port_to_hex "$port")
        bpftool map update id $TCP_MAP key hex $HEX_PORT value hex 01 00 00 00
    fi
done

UDP_PORTS=$(grep "^UDP_IN\s*=" "$CSF_CONF" | cut -d'"' -f2 | tr ',' ' ')
for port in $UDP_PORTS; do
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        HEX_PORT=$(port_to_hex "$port")
        bpftool map update id $UDP_MAP key hex $HEX_PORT value hex 01 00 00 00
    fi
done

# 5. Enable Strict Modes if defined in csf.conf
if grep -q "^RT_TCP_XDP_STRICT = \"1\"" "$CSF_CONF"; then
    echo "    > RT_TCP_XDP_STRICT is ENABLED."
    bpftool map update id $STRICT_MAP key hex 00 00 00 00 value hex 01
fi

if grep -q "^RT_UDP_XDP_STRICT = \"1\"" "$CSF_CONF"; then
    echo "    > RT_UDP_XDP_STRICT is ENABLED."
    bpftool map update id $STRICT_MAP key hex 01 00 00 00 value hex 01
fi

# 6. Push csf.deny into the XDP blocked_ips map with targeted Actions
# Determine global action from csf.conf
DROP_SETTING=$(grep -E '^\s*DROP\s*=' "$CSF_CONF" | sed -e 's/ //g' -e 's/"//g' | cut -d'=' -f2)
ACTION_HEX="00" # Default DROP
case "$DROP_SETTING" in
    TARPIT) ACTION_HEX="01" ;;
    ECHO)   ACTION_HEX="02" ;;
    CHAOS)  ACTION_HEX="03" ;;
esac

echo "    > Injecting Blocklist to NIC driver (Action: $DROP_SETTING)..."
if [ -f "$DENY_PERM" ]; then
    grep -vE "^#|^$" "$DENY_PERM" | awk '{print $1}' | while read -r IP; do
        if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            HEX_IP=$(ip_to_hex "$IP")
            bpftool map update id $BLOCKED_MAP key hex $HEX_IP value hex $ACTION_HEX
        fi
    done
fi

echo "[+] XDP Shield Active. Packets are now managed at L2/L3 hardware layer."
