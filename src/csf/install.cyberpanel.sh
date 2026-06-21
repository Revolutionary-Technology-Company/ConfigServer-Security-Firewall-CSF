#!/bin/bash
[ "$EUID" -ne 0 ] && echo "FATAL ERROR: You must run this installer as root." && exit 1

echo ""
echo " Configuring ConfigServer Security and Firewall"
echo " Revolutionary Technology Enterprise Edition - CyberPanel"
echo ""

STREAMING_CHUNK: Building core directory structures...

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

STREAMING_CHUNK: Deploying base firewall configurations...

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

STREAMING_CHUNK: Deploying Revolutionary Technology Enterprise Modules...

echo "Deploying Revolutionary Technology Enterprise Modules..."
cp -af rt-.sh csf-.sh install-.sh remove_.sh stressengine.sh make_ui_cert.sh compile_xdp.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af rt_omni_setup.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af xdp_echo.c /etc/csf/ >/dev/null 2>&1 || true

cp -af rt-*.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true
cp -af auto.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true

[ -d "plugins" ] && cp -af plugins/.py /etc/csf/plugins/ >/dev/null 2>&1 || true
[ -d "bin" ] && cp -af bin/.py /usr/local/csf/bin/ >/dev/null 2>&1 || true
[ -f "csf_telemetry_bridge.py" ] && cp -af csf_telemetry_bridge.py /etc/csf/plugins/ >/dev/null 2>&1 || true

chmod 700 /etc/csf/rt-.sh /etc/csf/csf-.sh /etc/csf/install-.sh /etc/csf/remove_.sh /etc/csf/compile_xdp.sh /etc/csf/stressengine.sh /etc/csf/make_ui_cert.sh /etc/csf/rt_omni_setup.sh >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/rt-.pl >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/.py >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/auto.pl >/dev/null 2>&1 || true
chmod 700 /etc/csf/plugins/*.py >/dev/null 2>&1 || true

STREAMING_CHUNK: Injecting Aegis Tactical Ports and Gemini AI V2...

if [ -f "/etc/csf/csf.conf" ]; then
grep -q "7400:7500" /etc/csf/csf.conf
if [ $? -ne 0 ]; then
echo "Injecting Aegis Tactical Ports safely..."
sed -i 's/^TCP_IN = "/TCP_IN = "7400:7500,9999,/' /etc/csf/csf.conf
sed -i 's/^UDP_IN = "/UDP_IN = "7400:7500,/' /etc/csf/csf.conf
fi

grep -q '^BLOCK_REPORT = ""' /etc/csf/csf.conf
if [ $? -eq 0 ]; then
    echo "Hooking Gemini AI V2..."
    sed -i 's|^BLOCK_REPORT = .*$|BLOCK_REPORT = "/etc/csf/plugins/csf_gemini_manager.py"|' /etc/csf/csf.conf
fi


fi

STREAMING_CHUNK: Integrating with CyberPanel...

echo "Integrating with CyberPanel..."
if [ -f "/etc/csf/csf.conf" ]; then
sed -i 's/^GENERIC = "1"/GENERIC = "0"/' /etc/csf/csf.conf
sed -i 's/^CYBERPANEL = "0"/CYBERPANEL = "1"/' /etc/csf/csf.conf
fir

STREAMING_CHUNK: Registering systemd daemons...

/local/cwpsrv/htdocs/resources/admin/modules/csf >/dev/null 2>&1 || true
ifl/; t "/etc/csf/csf.conf" ]; then
sed -i 's/^GENERIC = "1"/GENERIC = "0"/' /etc/csf/csf.conf
sed -i 's/^CWP = "0"/CWP = "1"/' /etc/csf/csf.confistering systemd daemons...

echo "Registering systemd daemons..."
if [ -d "/etc/systemd/system" ]; then
if [ -f "csf.service" ]; then
cp -af csf.service /etc/systemd/system/csf.service
cp -af lfd.service /etc/systemd/system/lfd.service
systemctl daemon-reload
systemctl enable csf.service >/dev/null 2>&1 || true
systemctl enable lfd.service >/dev/null 2>&1 || true
fi
fi

STREAMING_CHUNK: Initializing System Hooks...

echo "Initializing System Hooks..."
[ -x "/etc/csf/rt_omni_setup.sh" ] && /etc/csf/rt_omni_setup.sh || true

[ ! -x "/etc/csf/rt_omni_setup.sh" ] && [ -x "/etc/csf/install-apparmor.sh" ] && /etc/csf/install-apparmor.sh || true
[ ! -x "/etc/csf/rt_omni_setup.sh" ] && [ -x "/etc/csf/install-suricata.sh" ] && /etc/csf/install-suricata.sh || true

STREAMING_CHUNK: Starting CSF and LFD Services...

echo "Starting CSF and LFD Services..."
systemctl start csf >/dev/null 2>&1 || /usr/sbin/csf -s
systemctl start lfd >/dev/null 2>&1 || /usr/sbin/lfd

echo ""
echo "RT Deployment Sequence Complete!"
echo ""
exit 0
