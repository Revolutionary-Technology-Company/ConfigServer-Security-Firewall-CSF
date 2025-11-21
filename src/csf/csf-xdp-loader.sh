#!/bin/bash
# #
#   @script             Revolutionary Technology XDP Shield (v3.1 - Pure)
#   @description        High-Performance BPF/XDP Filter Loader.
#                       Enforces "Block All Except TCP_IN/UDP_IN" at the driver level.
#                       Legitimate traffic is passed to OS/CSF. Garbage is dropped.
# #

CSF_CONF="/etc/csf/csf.conf"

# Auto-detect the primary network interface
IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)

# Sanity Checks
if [ -z "$IFACE" ]; then
    echo "Error: Could not detect primary network interface."
    exit 1
fi

if ! command -v xdp-filter >/dev/null 2>&1; then
    echo "Error: xdp-filter (xdp-tools) is not installed. Cannot load Shield."
    exit 1
fi

# Helper function to extract clean port lists from csf.conf
get_config() {
    grep "^$1\s*=" "$CSF_CONF" | cut -d'"' -f2
}

start_shield() {
    echo "[XDP-Shield] Interface: $IFACE"
    
    # 1. Clean start: Remove any existing filters
    xdp-filter unload "$IFACE" >/dev/null 2>&1
    ip link set dev "$IFACE" xdp off >/dev/null 2>&1

    # 2. Load the "Steel Shield" (Default Policy: DROP)
    #    -f ipv4,ipv6  : Handle both protocols
    #    -m native     : Use Driver mode (Fastest)
    #    -p deny       : DROP everything not explicitly allowed below
    echo "[XDP-Shield] Loading Core Filter (Policy: DROP ALL)..."
    
    if xdp-filter load "$IFACE" -f ipv4,ipv6 -m native -p deny; then
        echo "    > Loaded in NATIVE (Driver) mode."
    else
        echo "    > Native mode failed. Falling back to SKB (Generic) mode..."
        xdp-filter load "$IFACE" -f ipv4,ipv6 -m skb -p deny
    fi

    # 3. Whitelist TCP Business Ports
    TCP_PORTS=$(get_config "TCP_IN" | tr ',' ' ')
    echo "[XDP-Shield] Opening TCP Ports: $TCP_PORTS"
    
    for port in $TCP_PORTS; do
        # Only process valid integers (skip ranges like 30000:35000 for basic xdp-filter)
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            xdp-filter port "$port" -p tcp -m allow >/dev/null 2>&1
        fi
    done
    
    # 4. Whitelist UDP Business Ports
    UDP_PORTS=$(get_config "UDP_IN" | tr ',' ' ')
    echo "[XDP-Shield] Opening UDP Ports: $UDP_PORTS"
    
    for port in $UDP_PORTS; do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            xdp-filter port "$port" -p udp -m allow >/dev/null 2>&1
        fi
    done

    # 5. Critical Failsafes (SSH & DNS)
    # Ensure you don't lock yourself out even if config is empty
    xdp-filter port 22 -p tcp -m allow >/dev/null 2>&1
    # Allow DNS responses if you run a DNS server or need lookup
    xdp-filter port 53 -p udp -m allow >/dev/null 2>&1

    echo "[XDP-Shield] Active. All unlisted ports are now dropped at the driver."
}

stop_shield() {
    echo "[XDP-Shield] Unloading..."
    xdp-filter unload "$IFACE" >/dev/null 2>&1
    ip link set dev "$IFACE" xdp off >/dev/null 2>&1
    echo "[XDP-Shield] Stopped."
}

case "$1" in
    start) start_shield ;;
    stop) stop_shield ;;
    restart) stop_shield; sleep 1; start_shield ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac