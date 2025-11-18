#!/bin/sh
# #
#   @app                ConfigServer Firewall & Security (CSF)
#   @script             BPF/XDP Rule Loader
#   @desc               Loads eBPF/XDP rules onto network interfaces at startup.
#                       Called by csfpre.sh.
#   @website            https://configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Dr. Correo Hofstad
#                       Copyright (C) 2025-2026 Dr. Cory 'Aetherinox' Hofstad Jr.
#                       Copyright (C) 2025-2026 Revolutionary Technology Revolutionarytechnology.net
#   @license            GPLv3
#   @updated            11.17.2025
# #

# #
#   This script finds all physical network interfaces and attempts to load a
#   corresponding eBPF/XDP program from the bpf.d directory.
#
#   For example, for interface "eth0", it will look for:
#   /etc/csf/bpf.d/eth0.o
#
#   It attaches the program to the "xdp" hook for maximum performance.
# #

# #
#   Define Paths
# #
BPF_RULES_DIR="/etc/csf/bpf.d"
IP_BIN=$(command -v ip)
# BPFTOOL_BIN=$(command -v bpftool) # For more advanced future use

# #
#   Include global.sh for logging functions, if it exists
# #
GLOBAL_SH="/usr/local/csf/bin/global.sh"
if [ -f "$GLOBAL_SH" ]; then
    . "$GLOBAL_SH"
else
    # Fallback logging functions if global.sh is not found
    esc=$(printf '\033')
    end="${esc}[0m"
    bold="${esc}[1m"
    redl="${esc}[0;91m"
    bluel="${esc}[38;5;75m"
    greenl="${esc}[38;5;76m"
    greym="${esc}[38;5;244m"
    
    error() { printf '%-28s %-65s\n' "  ${redl} ERROR ${end}" "${greym} $1 ${end}"; }
    warn() { printf '%-32s %-65s\n' "  ${yellowl} WARN ${end}" "${greym} $1 ${end}"; }
    status() { printf '%-31s %-65s\n' "  ${bluel} STATUS ${end}" "${greym} $1 ${end}"; }
    ok() { printf '%-31s %-65s\n' "  ${greenl} OK ${end}" "${greym} $1 ${end}"; }
    print() { printf '%-31s %-65s\n' "  ${peach}        ${end}" "${peach} $1 ${end}"; }
fi

status "BPF Loader: Starting BPF/XDP rule loading process..."

if [ ! -x "$IP_BIN" ]; then
    error "BPF Loader: 'ip' command not found. Cannot load BPF rules. Aborting."
    exit 1
fi

if [ ! -d "$BPF_RULES_DIR" ]; then
    warn "BPF Loader: Rules directory not found: $BPF_RULES_DIR. Skipping."
    exit 0
fi

# #
#   Find all physical (and vlan/bridge) interfaces
#   - Ignores loopback, virtual, etc.
# #
INTERFACES=$(ls -1 /sys/class/net | grep -vE '^(lo|docker|veth|virbr|vnet|tap)')

if [ -z "$INTERFACES" ]; then
    warn "BPF Loader: No physical network interfaces found to attach rules."
    exit 0
fi

# #
#   Loop through each interface and apply rules
# #
for IFACE in $INTERFACES; do
    RULE_FILE="${BPF_RULES_DIR}/${IFACE}.o"
    
    status "BPF Loader: Checking interface: ${bluel}$IFACE${greym}"
    
    # --- 1. Unload any existing XDP program first ---
    # This ensures a clean state and allows for rule reloading.
    # We check if an XDP program is already attached.
    if "$IP_BIN" link show dev "$IFACE" | grep -q "xdp obj"; then
        print "    > Found existing XDP program. Unloading..."
        "$IP_BIN" link set dev "$IFACE" xdp off >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            ok "    > Unloaded old program from $IFACE."
        else
            error "    > FAILED to unload XDP program from $IFACE. Skipping."
            continue
        fi
    else
        print "    > No existing XDP program found. Ready for loading."
    fi

    # --- 2. Check if a rule file exists for this interface ---
    if [ ! -f "$RULE_FILE" ]; then
        warn "    > No rule file found at $RULE_FILE. Skipping interface $IFACE."
        continue
    fi
    
    # --- 3. Load the new XDP program ---
    print "    > Found rule: $RULE_FILE. Attaching to $IFACE..."
    "$IP_BIN" link set dev "$IFACE" xdp obj "$RULE_FILE" sec xdp >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        ok "    > ${greenl}Successfully loaded and attached BPF program to $IFACE.${greym}"
    else
        error "    > ${redl}FAILED to load BPF program $RULE_FILE on $IFACE.${greym}"
        error "    > This may be due to a kernel/driver incompatibility or an error in the BPF code."
    fi
done

ok "BPF Loader: Finished processing all interfaces."