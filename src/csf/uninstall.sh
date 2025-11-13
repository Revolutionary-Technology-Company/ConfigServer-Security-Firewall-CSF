#!/bin/sh
echo "Uninstalling csf and lfd..."
echo

# Stop and flush the firewall
/usr/sbin/csf -f

if test `cat /proc/1/comm` = "systemd"; then
    # Stop and disable csf/lfd
    systemctl disable csf.service
    systemctl disable lfd.service
    systemctl stop csf.service
    systemctl stop lfd.service

    # [NEW] Stop and disable ModSec3 Bridge
    echo "Stopping ModSec3 Converter service..."
    systemctl disable modsec3-converter.service >/dev/null 2>&1
    systemctl stop modsec3-converter.service

    # [NEW] Stop and disable RPS Tuner service
    echo "Stopping RPS Tuner service..."
    systemctl disable csf-rps-tuner.service >/dev/null 2>&1
    systemctl stop csf-rps-tuner.service

    rm -fv /usr/lib/systemd/system/csf.service
    rm -fv /usr/lib/systemd/system/lfd.service
    
    # [NEW] Remove ModSec3 Bridge service file
    rm -fv /etc/systemd/system/modsec3-converter.service
    
    # [NEW] Remove RPS Tuner service file
    rm -fv /etc/systemd/system/csf-rps-tuner.service
    
    systemctl daemon-reload
else
    # Handle non-systemd init systems
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

# Remove cPanel integration
if [ -e "/usr/local/cpanel/bin/unregister_appconfig" ]; then
    echo "Unregistering cPanel app..."
    cd /
	/usr/local/cpanel/bin/unregister_appconfig csf
fi

# Remove chkservd integration
rm -fv /etc/chkserv.d/lfd
rm -fv /var/run/chkservd/lfd
if [ -f /etc/chkserv.d/chkservd.conf ]; then
    sed -i 's/lfd:1//' /etc/chkserv.d/chkservd.conf
    /scripts/restartsrv_chkservd > /dev/null 2>&1
fi

# Remove csf/lfd binaries and cron jobs
echo "Removing binaries and cron jobs..."
rm -fv /usr/sbin/csf
rm -fv /usr/sbin/lfd
rm -fv /etc/cron.d/csf_update
rm -fv /etc/cron.d/lfd-cron
rm -fv /etc/cron.d/csf-cron
rm -fv /etc/logrotate.d/lfd
rm -fv /usr/local/man/man1/csf.man.1

# Remove cPanel UI files
rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/addon_csf.cgi
rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/csf
rm -fv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf
rm -fv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf.pm
rm -Rfv /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
if [ -f /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver ]; then
    /bin/touch /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver
fi

# [NEW] Remove Auto-Tuner files
echo "Removing Auto-Tuner files..."
rm -fv /usr/local/sbin/csf-autotune.sh
rm -fv /etc/sysctl.d/99-csf-tuning.conf

# [NEW] Remove ModSec3 Bridge files
echo "Removing ModSec3 Bridge files..."
rm -fv /usr/local/sbin/modsec3_converter.pl

# Remove all csf data and config directories
echo "Removing data and configuration directories..."
rm -Rfv /etc/csf
rm -Rfv /usr/local/csf
rm -Rfv /var/lib/csf

echo
echo "...Good luck!"