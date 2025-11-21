#!/bin/sh
###############################################################################
#
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @website            https://configserver.shop
#   @description        Universal Uninstaller for Revolutionary Technology CSF/LFD
#
###############################################################################

echo "---------------------------------------------------------------"
echo "Revolutionary Technology - ConfigServer Security & Firewall Uninstaller"
echo "Copyright (C) 2025-2026 Dr. Correo Hofstad"
echo "---------------------------------------------------------------"
echo ""

# --- 1. Stop Services ---
echo "Stopping dynamic services (LFD, GSB Poller, XDP Shield)..."

# Robust Service Stopping (Systemd vs Init.d)
if [ -d "/etc/systemd/system" ] && command -v systemctl >/dev/null 2>&1; then
    systemctl stop lfd.service >/dev/null 2>&1
    systemctl stop csf.service >/dev/null 2>&1
    systemctl stop modsec3-converter.service >/dev/null 2>&1
    systemctl stop rt-gsb-poller.service >/dev/null 2>&1
    systemctl stop csf-xdp-loader.service >/dev/null 2>&1
    
    # Disable them
    systemctl disable lfd.service >/dev/null 2>&1
    systemctl disable csf.service >/dev/null 2>&1
    systemctl disable modsec3-converter.service >/dev/null 2>&1
    systemctl disable rt-gsb-poller.service >/dev/null 2>&1
    systemctl disable csf-xdp-loader.service >/dev/null 2>&1
else
    # Fallback
    /etc/init.d/lfd stop >/dev/null 2>&1
    /etc/init.d/csf stop >/dev/null 2>&1
fi

# --- 2. Flush Firewalls ---
echo "Flushing firewall rules..."
/usr/sbin/csf -f >/dev/null 2>&1
iptables --flush >/dev/null 2>&1
if command -v xdp-filter >/dev/null 2>&1; then
    # Attempt to unload XDP from primary interface
    IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
    if [ -n "$IFACE" ]; then
        xdp-filter unload "$IFACE" >/dev/null 2>&1
        ip link set dev "$IFACE" xdp off >/dev/null 2>&1
    fi
fi

# --- 3. Remove Revolutionary Technology Tools ---
echo "Removing Revolutionary Technology Tools..."
rm -fv /usr/local/sbin/csf-autotune.sh
rm -fv /usr/local/sbin/csf-firmware-check.sh
rm -fv /usr/local/sbin/stressengine.sh
rm -fv /usr/local/sbin/rt-sign-module.sh
rm -fv /usr/local/sbin/rt-csf-update.sh
rm -fv /usr/local/sbin/rt-gsb-poller.sh
rm -fv /usr/local/sbin/rt-block-reporter.sh
rm -fv /usr/local/sbin/rt-google-ip-updater.pl
rm -fv /usr/local/sbin/csf-xdp-loader.sh
rm -fv /usr/local/sbin/modsec3_converter.pl

# Remove source code and BPF objects
rm -Rfv /usr/local/csf/bpf

# Remove Cron Jobs
rm -fv /etc/cron.hourly/rt-block-reporter
rm -fv /etc/cron.d/rt-google-ip-updater

# Remove Systemd Units
rm -fv /etc/systemd/system/modsec3-converter.service
rm -fv /etc/systemd/system/rt-gsb-poller.service
rm -fv /etc/systemd/system/csf-xdp-loader.service
rm -fv /usr/lib/systemd/system/csf.service
rm -fv /usr/lib/systemd/system/lfd.service
if [ -d "/etc/systemd/system" ]; then
    systemctl daemon-reload >/dev/null 2>&1
fi

# --- 4. Clean Up Configuration ---
echo "Cleaning up configuration..."

# Remove Google IPs from csf.allow
if [ -f "/etc/csf/csf.allow" ]; then
    sed -i '/^# BEGIN Revolutionary Technology Google IPs/,/^# END Revolutionary Technology Google IPs/d' /etc/csf/csf.allow >/dev/null 2>&1
    sed -i '/# Google ASN/d' /etc/csf/csf.allow >/dev/null 2>&1
fi

# Remove sysctl hardening
if grep -q "net.ipv4.tcp_syncookies" /etc/sysctl.conf; then
    sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
fi

# --- 5. Core Uninstall ---
echo "Removing core CSF/LFD files..."

# Remove init scripts
if [ -f /etc/redhat-release ]; then
    /sbin/chkconfig csf off
    /sbin/chkconfig lfd off
    /sbin/chkconfig csf --del
    /sbin/chkconfig lfd --del
elif [ -x "/usr/sbin/update-rc.d" ]; then
    update-rc.d -f lfd remove
    update-rc.d -f csf remove
fi
rm -fv /etc/init.d/csf
rm -fv /etc/init.d/lfd

# Remove binaries and crons
rm -fv /usr/sbin/csf
rm -fv /usr/sbin/lfd
rm -fv /etc/cron.d/csf_update
rm -fv /etc/cron.d/lfd-cron
rm -fv /etc/cron.d/csf-cron
rm -fv /etc/logrotate.d/lfd
rm -fv /usr/local/man/man1/csf.man.1

# --- 6. Control Panel Cleanup ---

# cPanel
if [ -d "/usr/local/cpanel" ]; then
    echo "Removing cPanel integration..."
    if [ -x "/usr/local/cpanel/bin/unregister_appconfig" ]; then
        /usr/local/cpanel/bin/unregister_appconfig csf >/dev/null 2>&1
    fi
    rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_csf.cgi
    rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/csf
    rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
    rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf
    rm -fv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf.pm
    rm -Rfv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
fi

# DirectAdmin
if [ -d "/usr/local/directadmin" ]; then
    echo "Removing DirectAdmin integration..."
    sed -i 's/lfd=ON/lfd=OFF/' /usr/local/directadmin/data/admin/services.status >/dev/null 2>&1
    rm -Rfv /usr/local/directadmin/plugins/csf
fi

# Webmin
if [ -d "/usr/libexec/webmin/csf" ]; then rm -Rfv /usr/libexec/webmin/csf; fi
if [ -d "/usr/share/webmin/csf" ]; then rm -Rfv /usr/share/webmin/csf; fi

# InterWorx
if [ -d "/usr/local/interworx" ]; then
    rm -Rfv /usr/local/interworx/plugins/configservercsf
fi

# --- 7. Remove Data Directories ---
echo "Removing data directories..."
rm -Rfv /etc/csf
rm -Rfv /usr/local/csf
rm -Rfv /var/lib/csf
rm -Rfv /usr/local/include/csf

echo ""
echo "Uninstallation Complete."
echo "Revolutionary Technology Firewall Engine has been removed."
echo ""