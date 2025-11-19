#!/bin/bash
# #
#   @app                ConfigServer Firewall & Security (CSF)
#   @script             BPF/XDP Rule Loader & Map Populator
#   @desc               Loads compiled BPF bytecode and populates kernel maps
#                       from csf.conf settings.
#   @website            https://configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @license            GPLv3
# #

# #
#   Define Paths & Tools
# #
BPF_PROG="/etc/csf/bpf.d/csf_xdp_drop.o"
CSF_CONF="/etc/csf/csf.conf"
IP_BIN=$(command -v ip)
BPFTOOL_BIN=$(command -v bpftool)

# #
#   Include global.sh for logging functions
# #
GLOBAL_SH="/etc/csf/global.sh"
if [ ! -f "$GLOBAL_SH" ]; then GLOBAL_SH="/usr/local/csf/lib/global.sh"; fi
if [ -f "$GLOBAL_SH" ]; then
    . "$GLOBAL_SH"
else
    # Minimal fallback logging
    print() { echo "  $1"; }
    ok()    { echo "  [OK] $1"; }
    error() { echo "  [ERR] $1"; }
    warn()  { echo "  [WARN] $1"; }
fi

# #
#   1. Pre-Flight Checks
# #
if [ ! -x "$IP_BIN" ]; then
    error "BPF Loader: 'ip' command not found. Aborting."
    exit 1
fi

# Check for bpftool (Required for map population)
if [ ! -x "$BPFTOOL_BIN" ]; then
    warn "BPF Loader: 'bpftool' not found. XDP will load but Maps cannot be populated."
    warn "            Zero Trust features will not function correctly."
fi

if [ ! -f "$BPF_PROG" ]; then
    error "BPF Loader: BPF Object file not found at $BPF_PROG"
    exit 1
fi

# #
#   2. Read Configuration from csf.conf
# #
print "Reading configuration from $CSF_CONF..."

# Extract values using grep to avoid sourcing the whole file
RT_UDP_STRICT=$(grep "^RT_UDP_XDP_STRICT" "$CSF_CONF" | cut -d'"' -f2)
RT_TCP_STRICT=$(grep "^RT_TCP_XDP_STRICT" "$CSF_CONF" | cut -d'"' -f2)
UDP_IN_LIST=$(grep "^UDP_IN" "$CSF_CONF" | cut -d'"' -f2)
TCP_IN_LIST=$(grep "^TCP_IN" "$CSF_CONF" | cut -d'"' -f2)

# Set defaults if missing
: "${RT_UDP_STRICT:=0}"
: "${RT_TCP_STRICT:=0}"

# #
#   3. Detect Interface (Auto-detect main WAN interface)
# #
# Tries to find the interface with the default route
IFACE=$($IP_BIN route get 1.1.1.1 | grep -oP 'dev \K\S+' | head -n1)

if [ -z "$IFACE" ]; then
    error "BPF Loader: Could not detect primary network interface."
    exit 1
fi

print "Target Interface: ${bluel}$IFACE${greym}"

# #
#   4. Load XDP Program
# #

# Unload existing to ensure clean state
"$IP_BIN" link set dev "$IFACE" xdp off >/dev/null 2>&1

# Load new program
print "Loading XDP program into kernel..."
"$IP_BIN" link set dev "$IFACE" xdp obj "$BPF_PROG" sec xdp >/dev/null 2>&1

if [ $? -ne 0 ]; then
    error "Failed to load XDP program on $IFACE. Check kernel compatibility."
    exit 1
fi

ok "XDP Program loaded successfully."

# #
#   5. Populate BPF Maps
# #
if [ -x "$BPFTOOL_BIN" ]; then
    print "Populating BPF Maps..."

    # --- A. Configure Flags (Strict Mode) ---
    # Get ID for 'csf_conf_map'
    CONF_MAP_ID=$($BPFTOOL_BIN map show | grep csf_conf_map | awk '{print $1}' | tr -d ':')

    if [ ! -z "$CONF_MAP_ID" ]; then
        # Key 0 = UDP Strict Mode
        $BPFTOOL_BIN map update id $CONF_MAP_ID key 0 0 0 0 value $RT_UDP_STRICT 0 0 0
        # Key 1 = TCP Strict Mode
        $BPFTOOL_BIN map update id $CONF_MAP_ID key 1 0 0 0 value $RT_TCP_STRICT 0 0 0
        ok "Configuration flags pushed to kernel."
    else
        warn "Could not find 'csf_conf_map' in loaded program."
    fi

    # --- B. Populate UDP Whitelist ---
    if [ "$RT_UDP_STRICT" == "1" ]; then
        print "UDP Zero Trust Mode: ON. Populating whitelist..."
        UDP_MAP_ID=$($BPFTOOL_BIN map show | grep csf_udp_allow_map | awk '{print $1}' | tr -d ':')
        
        if [ ! -z "$UDP_MAP_ID" ]; then
            IFS=',' read -ra PORTS <<< "$UDP_IN_LIST"
            for port in "${PORTS[@]}"; do
                # Check if port is a valid integer (skip ranges for now)
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    # Update Map: Key=Port, Value=1
                    $BPFTOOL_BIN map update id $UDP_MAP_ID key $port 0 0 0 value 1 0 0 0
                fi
            done
            ok "UDP Whitelist populated."
        fi
    else
        print "UDP Zero Trust Mode: OFF."
    fi

    # --- C. Populate TCP Whitelist ---
    if [ "$RT_TCP_STRICT" == "1" ]; then
        print "TCP Zero Trust Mode: ON. Populating whitelist..."
        TCP_MAP_ID=$($BPFTOOL_BIN map show | grep csf_tcp_allow_map | awk '{print $1}' | tr -d ':')
        
        if [ ! -z "$TCP_MAP_ID" ]; then
            IFS=',' read -ra PORTS <<< "$TCP_IN_LIST"
            for port in "${PORTS[@]}"; do
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    $BPFTOOL_BIN map update id $TCP_MAP_ID key $port 0 0 0 value 1 0 0 0
                fi
            done
            ok "TCP Whitelist populated."
        fi
    else
        print "TCP Zero Trust Mode: OFF."
    fi

else
    warn "Skipping map population (bpftool missing)."
fi

print "Revolutionary Technology BPF/XDP Engine Active."