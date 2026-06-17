#!/bin/sh
###############################################################################
#
#   @app                ConfigServer Firewall & Security (CSF)
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @description        FINAL Universal Uninstaller for NGFW Suite
#
###############################################################################

echo "---------------------------------------------------------------"
echo "Revolutionary Technology - ConfigServer Security & Firewall Uninstaller"
echo "---------------------------------------------------------------"
echo ""

# --- 1. Stop All Dynamic Services ---
echo "Stopping all services (LFD, XDP, Suricata, Sandbox, GSB)..."

# Define all services to stop (NGFW + Core)
SERVICES_TO_STOP="lfd csf modsec3-converter rt-gsb-poller csf-xdp-loader rt-sandbox-tarpit suricata apparmor"

if [ -d "/etc/systemd/system" ] && command -v systemctl >/dev/null 2>&1; then
    for svc in $SERVICES_TO_STOP; do
        systemctl stop $svc.service >/dev/null 2>&1
        systemctl disable $svc.service >/dev/null 2>&1
    done
else
    # Fallback for non-systemd (Best effort stop)
    /etc/init.d/lfd stop >/dev/null 2>&1
    /etc/init.d/csf stop >/dev/null 2>&1
    /etc/init.d/apparmor stop >/dev/null 2>&1
fi

# --- 2. Remove Firewall Rules & Hardening ---
echo "Removing Firewall Rules & Kernel Hooks..."
IPTABLES=$(which iptables || echo "/sbin/iptables")
IPSET=$(which ipset || echo "/usr/sbin/ipset")

# a. Flush XDP (Driver-level Shield)
IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
if command -v xdp-filter >/dev/null 2>&1 && [ -n "$IFACE" ]; then
    echo "    > Unloading XDP Shield from $IFACE."
    xdp-filter unload "$IFACE" >/dev/null 2>&1
    ip link set dev "$IFACE" xdp off >/dev/null 2>&1
fi

# b. Remove u32 SYN flood rules (Immediate Mitigation)
$IPTABLES -D INPUT -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP 2>/dev/null
$IPTABLES -D INPUT -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP 2>/dev/null

# Force unregister from WHM
if [ -x "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    /usr/local/cpanel/bin/unregister_appconfig csf >/dev/null 2>&1
fi

# Scrub the CGI directory
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/

# Scrub the Perl Drivers (This is what causes the mismatch!)
/bin/rm -fv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf.pm
/bin/rm -Rfv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
/bin/touch /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver

# c. Flush GSB ipset
if $IPSET list -n "rt_google_safesites" &>/dev/null; then
    $IPTABLES -D INPUT -m set --match-set rt_google_safesites src -j DROP 2>/dev/null
    $IPSET destroy rt_google_safesites
fi

# d. Restore kernel defaults (syncookies)
if grep -q "^net.ipv4.tcp_syncookies" /etc/sysctl.conf; then
    sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi

# e. Flush main CSF/LFD rules
/usr/sbin/csf -f >/dev/null 2>&1

# --- 3. Remove NGFW & RT Binaries / Scripts ---
echo "Removing NGFW components and scripts..."

# Scripts/Tools
rm -fv /usr/local/sbin/csf-autotune.sh
rm -fv /usr/local/sbin/csf-firmware-check.sh
rm -fv /usr/local/sbin/stressengine.sh
rm -fv /usr/local/sbin/rt-sign-module.sh
rm -fv /usr/local/sbin/rt-gsb-poller.sh
rm -fv /usr/local/sbin/rt-block-reporter.sh
rm -fv /usr/local/sbin/rt-google-ip-updater.pl
rm -fv /usr/local/sbin/csf-xdp-loader.sh
rm -fv /usr/local/sbin/modsec3_converter.pl
rm -fv /usr/local/sbin/rt-sandbox-tarpit.py

# Cron Jobs and Service Files
rm -fv /etc/cron.hourly/rt-block-reporter
rm -fv /etc/cron.d/rt-google-ip-updater
rm -fv /etc/systemd/system/csf-xdp-loader.service
rm -fv /etc/systemd/system/rt-gsb-poller.service
rm -fv /etc/systemd/system/modsec3-converter.service
rm -fv /etc/systemd/system/rt-sandbox-tarpit.service
rm -fv /usr/local/csf/bin/csfpost_suricata.sh # Suricata integration hook

# AppArmor Profiles
echo "Removing AppArmor profiles..."
rm -fv /etc/apparmor.d/usr.sbin.sshd
rm -fv /etc/apparmor.d/usr.sbin.httpd
rm -fv /etc/apparmor.d/usr.sbin.exim
# (Any additional profiles would also be removed here)

# --- 4. Clean up CSF/LFD Core ---
echo "Removing core CSF/LFD binaries and files..."
rm -fv /usr/sbin/csf
rm -fv /usr/sbin/lfd
rm -fv /usr/sbin/csf-autotune

# Remove init scripts and service links
if [ -d "/etc/systemd/system" ]; then
    rm -fv /usr/lib/systemd/system/csf.service
    rm -fv /usr/lib/systemd/system/lfd.service
else
    rm -fv /etc/init.d/csf
    rm -fv /etc/init.d/lfd
fi

# Clean Google IPs from csf.allow
echo "Cleaning Google IP entries from csf.allow..."
if [ -f /etc/csf/csf.allow ]; then
    sed -i '/^# BEGIN Revolutionary Technology Google IPs/,/^# END Revolutionary Technology Google IPs/d' /etc/csf/csf.allow > /dev/null 2>&1
    sed -i '/# Google ASN/d' /etc/csf/csf.allow > /dev/null 2>&1
fi

# --- 5. Final Data Removal ---
echo "Removing data directories..."
rm -Rfv /etc/csf
rm -Rfv /usr/local/csf
rm -Rfv /var/lib/csf
rm -Rfv /usr/local/include/csf

echo
echo "Uninstallation Complete."
echo "Revolutionary Technology Firewall Engine has been removed."
echo ""
