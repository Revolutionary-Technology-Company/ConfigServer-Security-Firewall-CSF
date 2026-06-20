#!/usr/bin/env bash
###############################################################################
#   @app                ConfigServer Security & Firewall (CSF)
#   @website            https://configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @description        Master Enterprise Omni-Installer
###############################################################################

echo "======================================================================"
echo " Configuring ConfigServer Security & Firewall (CSF)                   "
echo " Revolutionary Technology Enterprise Edition                          "
echo "======================================================================"

# ============================================================================
# 1. PRE-FLIGHT CHECKS
# ============================================================================
if [ "$EUID" -ne 0 ]; then
    echo "[-] FATAL ERROR: You must run this installer as root."
    exit 1
fi

echo "[*] Creating core directory structures..."
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

# ============================================================================
# 2. DEPLOY STANDARD CSF CORE FILES
# ============================================================================
echo "[*] Deploying base firewall configurations..."

# Copy Main Executables
cp -af csf.sh /usr/sbin/csf
cp -af lfd.sh /usr/sbin/lfd
chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd

# Copy Configurations (Only if they don't exist to prevent overwriting user data)
for file in csf.conf csf.allow csf.deny csf.ignore csf.pignore csf.fignore csf.mignore csf.signore csf.suignore csf.syslogusers csf.dirwatch csf.syslogs csf.sips csf.redirect; do
    if [ ! -f "/etc/csf/$file" ] && [ -f "$file" ]; then
        cp -af "$file" "/etc/csf/$file"
    fi
done

# Copy always-overwrite files (Blocklists, Profiles, Templates)
cp -af csf.blocklists /etc/csf/ >/dev/null 2>&1 || true
cp -af profiles /etc/csf/ >/dev/null 2>&1 || true
cp -af *alert.txt /usr/local/csf/tpl/ >/dev/null 2>&1 || true
cp -af regex.pm /usr/local/csf/lib/ >/dev/null 2>&1 || true

# ============================================================================
# 3. REVOLUTIONARY TECHNOLOGY: ENTERPRISE OMNI-DEPLOYMENT
# ============================================================================
echo "[*] Deploying Revolutionary Technology Enterprise Modules..."

# Copy ALL Custom Bash Scripts, C-Code, and Configurations
echo "  -> Copying shell modules..."
cp -af rt-*.sh csf-*.sh install-*.sh remove_*.sh stressengine.sh make_ui_cert.sh compile_xdp.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af rt_omni_setup.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af xdp_echo.c /etc/csf/ >/dev/null 2>&1 || true

# Copy Custom Perl Integrations
echo "  -> Copying Perl integrations..."
cp -af rt-*.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true
cp -af auto.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true

# Copy Python Enterprise Engines & Telemetry Bridges
echo "  -> Copying Python/Numba engines..."
if [ -d "plugins" ]; then
    cp -af plugins/*.py /etc/csf/plugins/ >/dev/null 2>&1 || true
fi
if [ -d "bin" ]; then
    cp -af bin/*.py /usr/local/csf/bin/ >/dev/null 2>&1 || true
fi
if [ -f "csf_telemetry_bridge.py" ]; then
    cp -af csf_telemetry_bridge.py /etc/csf/plugins/ >/dev/null 2>&1 || true
fi

# Apply Strict Execution Permissions
echo "  -> Locking down permissions..."
chmod 700 /etc/csf/rt-*.sh /etc/csf/csf-*.sh /etc/csf/install-*.sh /etc/csf/remove_*.sh /etc/csf/compile_xdp.sh /etc/csf/stressengine.sh /etc/csf/make_ui_cert.sh /etc/csf/rt_omni_setup.sh >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/rt-*.pl >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/*.py >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/auto.pl >/dev/null 2>&1 || true
chmod 700 /etc/csf/plugins/*.py >/dev/null 2>&1 || true

# GUARD CLAUSE: Idempotent Port Injections (Univac Aegis)
if [ -f "/etc/csf/csf.conf" ]; then
    if ! grep -q "7400:7500" /etc/csf/csf.conf; then
        echo "  -> Injecting Aegis Tactical Ports safely..."
        sed -i 's/^TCP_IN = "/TCP_IN = "7400:7500,9999,/' /etc/csf/csf.conf
        sed -i 's/^UDP_IN = "/UDP_IN = "7400:7500,/' /etc/csf/csf.conf
    fi

    # Hook the Gemini AI Manager into BLOCK_REPORT safely
    if grep -q '^BLOCK_REPORT = ""' /etc/csf/csf.conf; then
        echo "  -> Hooking Gemini AI V2..."
        sed -i 's|^BLOCK_REPORT = .*$|BLOCK_REPORT = "/etc/csf/plugins/csf_gemini_manager.py"|' /etc/csf/csf.conf
    fi
fi

# ============================================================================
# 4. SYSTEMD DAEMON REGISTRATION
# ============================================================================
echo "[*] Registering systemd daemons..."
if [ -d "/etc/systemd/system" ]; then
    if [ -f "csf.service" ]; then
        cp -af csf.service /etc/systemd/system/csf.service
        cp -af lfd.service /etc/systemd/system/lfd.service
        systemctl daemon-reload
        systemctl enable csf.service >/dev/null 2>&1 || true
        systemctl enable lfd.service >/dev/null 2>&1 || true
    fi
fi

# ============================================================================
# 5. EXECUTE SUB-INSTALLERS & ORCHESTRATORS
# ============================================================================
echo "[*] Initializing System Hooks..."
if [ -x "/etc/csf/rt_omni_setup.sh" ]; then
    echo "  -> Running Omni-Setup Orchestrator..."
    /etc/csf/rt_omni_setup.sh || true
else
    # Fallback to individual scripts if Omni isn't available
    if [ -x "/etc/csf/install-apparmor.sh" ]; then
        echo "  -> Running AppArmor Setup..."
        /etc/csf/install-apparmor.sh || true
    fi

    if [ -x "/etc/csf/install-suricata.sh" ]; then
        echo "  -> Running Suricata Setup..."
        /etc/csf/install-suricata.sh || true
    fi
fi

# ============================================================================
# 6. RESTART DAEMONS
# ============================================================================
echo "[*] Starting CSF and LFD Services..."
systemctl start csf >/dev/null 2>&1 || /usr/sbin/csf -s
systemctl start lfd >/dev/null 2>&1 || /usr/sbin/lfd

echo "======================================================================"
echo "[+] RT Deployment Sequence Complete!"
echo "======================================================================"
exit 0
