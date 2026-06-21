[ "$EUID" -ne 0 ] && echo "FATAL ERROR: You must run this uninstaller as root." && exit 1

echo "======================================================================"
echo " Uninstalling ConfigServer Security and Firewall"
echo " Revolutionary Technology Enterprise Edition"
echo "======================================================================"

echo "Stopping core services and Python daemons..."
systemctl stop csf >/dev/null 2>&1 || /usr/sbin/csf -x >/dev/null 2>&1 || true
systemctl stop lfd >/dev/null 2>&1 || killall -9 lfd >/dev/null 2>&1 || true
systemctl stop csf-isolation.service >/dev/null 2>&1 || true

echo "Disabling services..."
systemctl disable csf >/dev/null 2>&1 || true
systemctl disable lfd >/dev/null 2>&1 || true
systemctl disable csf-isolation.service >/dev/null 2>&1 || true

echo "Scrubbing systemd units..."
rm -fv /etc/systemd/system/csf.service
rm -fv /etc/systemd/system/lfd.service
rm -fv /etc/systemd/system/csf-isolation.service
systemctl daemon-reload >/dev/null 2>&1 || true

echo "Scrubbing primary executables..."
rm -fv /usr/sbin/csf
rm -fv /usr/sbin/lfd

echo "Scrubbing logrotate configurations..."
rm -fv /etc/logrotate.d/lfd

echo "Explicitly scrubbing RT sub-installers and telemetry bridges..."
rm -fv /usr/local/csf/bin/rt-suricata-integrator.pl
rm -fv /usr/local/csf/bin/rt-google-ip-updater.pl
rm -fv /etc/csf/rt-suricata-integrator.pl
rm -fv /etc/csf/rt-google-ip-updater.pl
rm -fv /etc/csf/install-apparmor.sh
rm -fv /etc/csf/install-suricata.sh
rm -fv /etc/csf/rt_omni_setup.sh

echo "Scrubbing core directories and all custom RT modules..."
rm -Rfv /etc/csf
rm -Rfv /var/lib/csf
rm -Rfv /usr/local/csf

echo "Scrubbing UI and Control Panel artifacts..."
[ -x "/usr/local/cpanel/bin/unregister_appconfig" ] && /usr/local/cpanel/bin/unregister_appconfig csf >/dev/null 2>&1 || true
rm -Rfv /usr/libexec/webmin/csf
rm -Rfv /etc/webmin/csf
rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/addon_csf.cgi
rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/csf
rm -Rfv /usr/local/cpanel/whostmgr/docroot/cgi/addon_csf
rm -Rfv /usr/local/directadmin/plugins/csf
rm -Rfv /home/interworx/plugins/csf
rm -Rfv /usr/local/vesta/web/list/csf

echo "Detaching XDP network hooks..."
command -v ip >/dev/null 2>&1 && for iface in $(ip link show | grep -B 1 "xdp" | grep -v "xdp" | awk -F': ' '{print $2}'); do
    ip link set dev "$iface" xdp off >/dev/null 2>&1
    echo "Removed XDP from $iface"
done

echo "Cleaning AppArmor profiles..."
[ -d "/etc/apparmor.d" ] && rm -fv /etc/apparmor.d/usr.sbin.csf
[ -d "/etc/apparmor.d" ] && rm -fv /etc/apparmor.d/usr.sbin.lfd
[ -d "/etc/apparmor.d" ] && command -v apparmor_parser >/dev/null 2>&1 && systemctl reload apparmor >/dev/null 2>&1 || true

echo "Removing custom polling cronjobs..."
rm -fv /etc/cron.d/rt-gsb-poller
rm -fv /etc/cron.d/csf-autotune
rm -fv /etc/cron.d/rt-suricata
rm -fv /etc/cron.hourly/rt-csf-update

echo "Scrubbing leftover custom log files..."
rm -fv /var/log/csf-xdp.log
rm -fv /var/log/csf-isolation.log
rm -fv /var/log/rt-suricata.log
rm -fv /var/log/csf_gemini.log

echo "======================================================================"
echo "Uninstallation Sequence Complete!"
echo "======================================================================"
exit 0
