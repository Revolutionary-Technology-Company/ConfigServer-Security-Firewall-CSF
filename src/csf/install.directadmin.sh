[ "$EUID" -ne 0 ] && echo "FATAL ERROR: You must run this installer as root." && exit 1
[ ! -d "/usr/local/directadmin" ] && echo "FATAL ERROR: DirectAdmin not found." && exit 1

echo "Configuring ConfigServer Security and Firewall for DirectAdmin"
echo "Revolutionary Technology Enterprise Edition"

echo "Creating core directory structures..."
mkdir -p /etc/csf
mkdir -p /etc/csf/plugins
mkdir -p /usr/local/csf/bin
mkdir -p /usr/local/csf/lib
mkdir -p /usr/local/csf/tpl
mkdir -p /var/lib/csf
mkdir -p /var/lib/csf/backup
mkdir -p /var/lib/csf/ui
mkdir -p /var/lib/csf/stats
mkdir -p /var/lib/csf/lock
mkdir -p /var/lib/csf/webmin

chmod 700 /etc/csf
chmod 700 /usr/local/csf/bin
chmod 700 /var/lib/csf

echo "Deploying base firewall configurations..."
cp -af csf.sh /usr/sbin/csf
cp -af lfd.sh /usr/sbin/lfd
chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd

for file in csf.conf csf.allow csf.deny csf.ignore csf.pignore csf.fignore csf.mignore csf.signore csf.suignore csf.syslogusers csf.dirwatch csf.syslogs csf.sips csf.redirect; do
    [ ! -f "/etc/csf/$file" ] && [ -f "$file" ] && cp -af "$file" "/etc/csf/$file"
done

cp -af csf.blocklists /etc/csf/ >/dev/null 2>&1 || true
cp -af profiles /etc/csf/ >/dev/null 2>&1 || true
cp -af *alert.txt /usr/local/csf/tpl/ >/dev/null 2>&1 || true
cp -af regex.pm /usr/local/csf/lib/ >/dev/null 2>&1 || true

echo "Deploying Revolutionary Technology Enterprise Modules..."
cp -af rt-*.sh csf-*.sh install-*.sh remove_*.sh stressengine.sh make_ui_cert.sh compile_xdp.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af rt_omni_setup.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af xdp_echo.c /etc/csf/ >/dev/null 2>&1 || true

cp -af rt-*.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true
cp -af auto*.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true

[ -d "plugins" ] && cp -af plugins/*.py /etc/csf/plugins/ >/dev/null 2>&1 || true
[ -d "bin" ] && cp -af bin/*.py /usr/local/csf/bin/ >/dev/null 2>&1 || true
[ -f "csf_telemetry_bridge.py" ] && cp -af csf_telemetry_bridge.py /etc/csf/plugins/ >/dev/null 2>&1 || true

chmod 700 /etc/csf/rt-*.sh /etc/csf/csf-*.sh /etc/csf/install-*.sh /etc/csf/remove_*.sh /etc/csf/compile_xdp.sh /etc/csf/stressengine.sh /etc/csf/make_ui_cert.sh /etc/csf/rt_omni_setup.sh >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/rt-*.pl >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/*.py >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/auto*.pl >/dev/null 2>&1 || true
chmod 700 /etc/csf/plugins/*.py >/dev/null 2>&1 || true

[ -f "/etc/csf/csf.conf" ] && grep -q "7400:7500" /etc/csf/csf.conf || sed -i 's/^TCP_IN = "/TCP_IN = "7400:7500,9999,/' /etc/csf/csf.conf
[ -f "/etc/csf/csf.conf" ] && grep -q "7400:7500" /etc/csf/csf.conf || sed -i 's/^UDP_IN = "/UDP_IN = "7400:7500,/' /etc/csf/csf.conf
[ -f "/etc/csf/csf.conf" ] && grep -q '^BLOCK_REPORT = ""' /etc/csf/csf.conf && sed -i 's|^BLOCK_REPORT = .*$|BLOCK_REPORT = "/etc/csf/plugins/csf_gemini_manager.py"|' /etc/csf/csf.conf

echo "Registering systemd daemons..."
[ -d "/etc/systemd/system" ] && [ -f "csf.service" ] && cp -af csf.service /etc/systemd/system/csf.service
[ -d "/etc/systemd/system" ] && [ -f "lfd.service" ] && cp -af lfd.service /etc/systemd/system/lfd.service
[ -d "/etc/systemd/system" ] && systemctl daemon-reload >/dev/null 2>&1 || true
[ -d "/etc/systemd/system" ] && systemctl enable csf.service >/dev/null 2>&1 || true
[ -d "/etc/systemd/system" ] && systemctl enable lfd.service >/dev/null 2>&1 || true

echo "Deploying DirectAdmin UI Plugin..."
mkdir -p /usr/local/directadmin/plugins/csf
cp -af directadmin/* /usr/local/directadmin/plugins/csf/ >/dev/null 2>&1 || true
chown -R diradmin:diradmin /usr/local/directadmin/plugins/csf >/dev/null 2>&1 || true
chmod -R 755 /usr/local/directadmin/plugins/csf >/dev/null 2>&1 || true
[ -x "/usr/local/csf/bin/auto.directadmin.pl" ] && /usr/local/csf/bin/auto.directadmin.pl || true

echo "Initializing System Hooks..."
[ -x "/etc/csf/rt_omni_setup.sh" ] && /etc/csf/rt_omni_setup.sh || true
[ ! -x "/etc/csf/rt_omni_setup.sh" ] && [ -x "/etc/csf/install-apparmor.sh" ] && /etc/csf/install-apparmor.sh || true
[ ! -x "/etc/csf/rt_omni_setup.sh" ] && [ -x "/etc/csf/install-suricata.sh" ] && /etc/csf/install-suricata.sh || true

echo "Starting CSF and LFD Services..."
systemctl start csf >/dev/null 2>&1 || /usr/sbin/csf -s
systemctl start lfd >/dev/null 2>&1 || /usr/sbin/lfd

echo "RT Deployment Sequence Complete!"
exit 0
