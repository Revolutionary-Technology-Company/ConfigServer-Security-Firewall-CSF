#!/bin/sh
echo "Uninstalling Revolutionary Technology Firewall Engine..."
echo

echo "Stopping dynamic services (LFD, NIC Accelerator, GSB Poller)..."
if test \`cat /proc/1/comm\` = "systemd"; then
    # Stop all our services first to freeze the state
    systemctl stop lfd.service >/dev/null 2>&1
    systemctl stop csf-nic-accelerator.service >/dev/null 2>&1
    systemctl stop modsec3-converter.service >/dev/null 2>&1
    systemctl stop rt-gsb-poller.service >/dev/null 2>&1
    # Stop bpfilterd if it's running
    systemctl stop bpfilterd.service >/dev/null 2>&1
else
    # Fallback for non-systemd
    /etc/init.d/lfd stop >/dev/null 2>&1
fi

echo "Removing Hardware-Accelerated rules (Stress Engine & GSB)..."
IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")

# Flush and remove Google Safe Sites ipset
if $IPSET list -n "rt_google_safesites" &>/dev/null; then
    echo "Removing Google Safe Sites firewall rules..."
    $IPTABLES -D INPUT -m set --match-set rt_google_safesites src -j DROP >/dev/null 2>&1
    $IPSET flush rt_google_safesites
    $IPSET destroy rt_google_safesites
fi

# Flush and remove Stress Engine chains
$IPTABLES -t raw -F RT_STRESS_ENGINE_RAW > /dev/null 2>&1
$IPTABLES -t raw -D PREROUTING -j RT_STRESS_ENGINE_RAW > /dev/null 2>&1
$IPTABLES -t raw -X RT_STRESS_ENGINE_RAW > /dev/null 2>&1
$IPTABLES -t filter -F RT_STRESS_ENGINE_FILTER > /dev/null 2>&1
$IPTABLES -D INPUT -j RT_STRESS_ENGINE_FILTER > /dev/null 2>&1
$IPTABLES -t filter -X RT_STRESS_ENGINE_FILTER > /dev/null 2>&1

# [NEW] Remove NFTables Tables (RT Emergency & RT Security)
if command -v nft >/dev/null 2>&1; then
    echo "Flushing Revolutionary Technology NFTables..."
    # Remove the Triage table from install
    nft delete table inet rt_emergency >/dev/null 2>&1
    # Remove the Stress Engine table
    nft delete table inet rt_security >/dev/null 2>&1
fi

echo "Removing custom SYN flood rules..."
iptables -D INPUT -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP >/dev/null 2>&1
iptables -D INPUT -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP >/dev/null 2>&1

# ... (Rest of the file remains the same)