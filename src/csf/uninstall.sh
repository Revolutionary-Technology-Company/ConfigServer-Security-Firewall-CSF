#!/bin/sh
echo "Uninstalling csf and lfd..."
echo

/usr/sbin/csf -f

if test `cat /proc/1/comm` = "systemd"; then
    systemctl disable csf.service
    systemctl disable lfd.service
    systemctl stop csf.service
    systemctl stop lfd.service

    rm -fv /usr/lib/systemd/system/csf.service
    rm -fv /usr/lib/systemd/system/lfd.service
    systemctl daemon-reload
else
    if [ -f /etc/redhat-release ]; then
        /sbin/chkconfig csf off
        /sbin/chkconfig lfd off
        /sbin/chkconfig csf --del
        /sbin/chkconfig lfd --del
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        update-rc.d -f lfd remove
        update-rc.d -f csf remove
    elif [ -f /etc/gentoo-release ]; then
        rc-update del lfd default
        rc-update del csf default
    elif [ -f /etc/slackware-version ]; then
        rm -vf /etc/rc.d/rc3.d/S80csf
        rm -vf /etc/rc.d/rc4.d/S80csf
        rm -vf /etc/rc.d/rc5.d/S80csf
        rm -vf /etc/rc.d/rc3.d/S85lfd
        rm -vf /etc/rc.d/rc4.d/S85lfd
        rm -vf /etc/rc.d/rc5.d/S85lfd
    else
        /sbin/chkconfig csf off
        /sbin/chkconfig lfd off
        /sbin/chkconfig csf --del
        /sbin/chkconfig lfd --del
    fi
    rm -fv /etc/init.d/csf
    rm -fv /etc/init.d/lfd
fi

if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    cd /
	/usr/local/cpanel/bin/unregister_appconfig csf
fi

rm -fv /etc/chkserv.d/lfd
rm -fv /usr/sbin/csf
rm -fv /usr/sbin/lfd
rm -fv /etc/cron.d/csf_update
rm -fv /etc/cron.d/lfd-cron
rm -fv /etc/cron.d/csf-cron
rm -fv /etc/logrotate.d/lfd
rm -fv /usr/local/man/man1/csf.man.1

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_csf.cgi
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/csf

/bin/rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
/bin/rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf

/bin/rm -fv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf.pm
/bin/rm -Rfv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
/bin/touch /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver

rm -fv /var/run/chkservd/lfd
sed -i 's/lfd:1//' /etc/chkserv.d/chkservd.conf
/scripts/restartsrv_chkservd

rm -Rfv /etc/csf /usr/local/csf /var/lib/csf

echo
echo "...Done"

#!/usr/bin/env bash
# ==============================================================================
# ConfigServer Security & Firewall - Core Uninstaller Hook
# Path: src/csf/uninstall.sh
# ==============================================================================

echo "==================================================================="
echo " CONFIGSERVER SECURITY & FIREWALL UNINSTALLER"
echo "==================================================================="

# 1. Execute the Advanced Extension Guard first
RT_CLEANER="/usr/local/csf/bin/rt_uninstall_engine.sh"
if [ -f "$RT_CLEANER" ]; then
    chmod +x "$RT_CLEANER"
    bash "$RT_CLEANER"
elif [ -f "./rt_uninstall_engine.sh" ]; then
    chmod +x "./rt_uninstall_engine.sh"
    bash "./rt_uninstall_engine.sh"
fi

# 2. Stop core heritage services
echo "[*] Shuts down firewall and legacy authentication watchers..."
if [ -f "/etc/init.d/lfd" ]; then
    /etc/init.d/lfd stop
elif command -v systemctl &>/dev/null; then
    systemctl stop lfd >/dev/null 2>&1
    systemctl stop csf >/dev/null 2>&1
fi

# 3. Clean environment integration maps (cPanel/DirectAdmin/Control Web Panel)
echo "[*] Removing control panel hooks and binary trees..."
if [ -f "/etc/chkserv.d/chkservd.conf" ]; then
    echo "    > De-registering LFD monitoring from tailwatchd trees..."
    sed -i '/^lfd:/d' /etc/chkserv.d/chkservd.conf
    rm -f /etc/chkserv.d/lfd
fi

# Strip standard execution links from sbin
rm -f /usr/sbin/csf
rm -f /usr/sbin/lfd
rm -f /usr/sbin/rt-csf-update

# Remove the installation configuration nodes completely
echo "[*] Purging configuration directories..."
rm -rf /etc/csf
rm -rf /var/lib/csf
rm -rf /usr/local/csf

# 4. Flush standard netfilter tables to prevent server locking
echo "[*] Restoring default interface access tables..."
iptables --flush
iptables --delete-chain
iptables -t nat --flush
iptables -t nat --delete-chain

if command -v ip6tables &>/dev/null; then
    ip6tables --flush >/dev/null 2>&1
    ip6tables --delete-chain >/dev/null 2>&1
fi

echo "==================================================================="
echo " UNINSTALL COMPLETE"
echo " Note: All hardware offloads, memory buffers, and Netfilter rules"
echo " have been cleared. Default interface networking is restored."
echo "==================================================================="
