#!/bin/sh
###############################################################################
#
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @website            https://configserver.shop
#   @description        Master Installer for Revolutionary Technology CSF/LFD
#                       (Includes XDP, Suricata, AppArmor, and Google Tools)
#
###############################################################################

echo "---------------------------------------------------------------"
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "Copyright (C) 2025-2026 Dr. Correo Hofstad"
echo "Master Installer v2.15.09"
echo "---------------------------------------------------------------"
echo ""

# --- 0. Sanitize Environment (The Windows Virus Fix) ---
if [ -n "$(command -v sed)" ]; then
    find . -type f -name "*.sh" -exec sed -i 's/\r$//' {} +
    find . -type f -name "*.pl" -exec sed -i 's/\r$//' {} +
    find . -type f -name "*.txt" -exec sed -i 's/\r$//' {} +
    find . -type f -name "*.conf" -exec sed -i 's/\r$//' {} +
    find . -type f -name "*.cgi" -exec sed -i 's/\r$//' {} +
    find . -type f -name "*.pm" -exec sed -i 's/\r$//' {} +
fi

# --- 1. Directory Setup ---
echo -n "Creating directory structure..."
mkdir -p /etc/csf/ui
mkdir -p /var/lib/csf
mkdir -p /usr/local/csf/bin
mkdir -p /usr/local/csf/lib
mkdir -p /usr/local/csf/tpl
mkdir -p /usr/local/csf/profiles
mkdir -p /usr/local/sbin
echo " done"

# --- 2. Install Libraries (The "Scavenger" Fix) ---
echo -n "Installing Perl libraries..."
# 1. Try copying from root folders if they exist (fixes your specific issue)
cp -afR ConfigServer /usr/local/csf/lib/ 2>/dev/null
cp -afR Net /usr/local/csf/lib/ 2>/dev/null
cp -afR Crypt /usr/local/csf/lib/ 2>/dev/null
cp -afR Geo /usr/local/csf/lib/ 2>/dev/null
cp -afR JSON /usr/local/csf/lib/ 2>/dev/null
cp -afR version /usr/local/csf/lib/ 2>/dev/null
cp -afR HTTP /usr/local/csf/lib/ 2>/dev/null

# 2. Try copying from lib/ folder if it exists (standard structure)
if [ -d "lib" ]; then
    cp -afR lib/* /usr/local/csf/lib/
fi

# 3. Permissions
chmod 700 /usr/local/csf/lib
chmod -R 700 /usr/local/csf/lib/*
echo " done"

# --- 3. Install Core Binaries ---
echo -n "Installing core binaries..."
# Helper to find files in root or subfolders
find_install() {
    src="$1"
    dest="$2"
    if [ -f "$src" ]; then
        cp -af "$src" "$dest"
    elif [ -f "cpanel/$src" ]; then
        cp -af "cpanel/$src" "$dest"
    elif [ -f "da/$src" ]; then
        cp -af "da/$src" "$dest"
    elif [ -f "generic/$src" ]; then
        cp -af "generic/$src" "$dest"
    fi
}

find_install "csf.pl" "/usr/sbin/csf"
find_install "lfd.pl" "/usr/sbin/lfd"
chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd
echo " done"

# --- 4. Install Revolutionary Technology Tools (From Google Doc) ---
echo -n "Installing RT Modules..."

# Define the tool list
TOOLS="csf-autotune.sh csf-firmware-check.sh stressengine.sh rt-sign-module.sh rt-csf-update.sh rt-gsb-poller.sh rt-block-reporter.sh rt-google-ip-updater.pl install-suricata.sh rt-suricata-integrator.pl install-apparmor.sh csf-xdp-loader.sh"

for tool in $TOOLS; do
    if [ -f "$tool" ]; then
        cp -af "$tool" "/usr/local/sbin/$tool"
        chmod 700 "/usr/local/sbin/$tool"
    fi
done
echo " done"

# ============================================================================
# REVOLUTIONARY TECHNOLOGY: CUSTOM MODULE DEPLOYMENT
# ============================================================================
echo "Deploying Custom RT Modules..."

# 1. Create custom directory structures
mkdir -p /etc/csf/plugins

# 2. Copy all custom bash scripts and configurations
cp -af rt-*.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af csf-*.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af stressengine.sh /etc/csf/ >/dev/null 2>&1 || true
cp -af make_ui_cert.sh /etc/csf/ >/dev/null 2>&1 || true

# 3. Copy Perl Integrations to the bin folder
cp -af rt-*.pl /usr/local/csf/bin/ >/dev/null 2>&1 || true

# 4. Copy Python Plugins safely
if [ -d "plugins" ]; then
    cp -af plugins/*.py /etc/csf/plugins/ >/dev/null 2>&1 || true
fi

# 5. Copy XDP C-source and compiler
cp -af xdp_echo.c /etc/csf/ >/dev/null 2>&1 || true
cp -af compile_xdp.sh /etc/csf/ >/dev/null 2>&1 || true

# 6. Apply strict execution permissions
chmod 700 /etc/csf/rt-*.sh /etc/csf/csf-*.sh /etc/csf/stressengine.sh /etc/csf/compile_xdp.sh >/dev/null 2>&1 || true
chmod 700 /usr/local/csf/bin/rt-*.pl >/dev/null 2>&1 || true
chmod 700 /etc/csf/plugins/*.py >/dev/null 2>&1 || true

# 7. Execute Sub-Installers
echo "Initializing Sub-Systems..."
if [ -f "install-apparmor.sh" ]; then
    sh install-apparmor.sh
fi

if [ -f "install-suricata.sh" ]; then
    sh install-suricata.sh
fi

# 8. Compile XDP if clang is present (Prevents loader crash)
if command -v clang >/dev/null 2>&1; then
    echo "Compiling XDP eBPF modules..."
    cd /etc/csf/ && sh compile_xdp.sh
    cd - >/dev/null
else
    echo "WARNING: 'clang' not found. XDP hardware offloading will be unavailable."
fi

echo "RT Modules deployed successfully."
# ============================================================================

# --- 5. Install Configuration & Profiles ---
echo -n "Installing configuration..."
if [ ! -f "/etc/csf/csf.conf" ]; then
    find_install "csf.conf" "/etc/csf/csf.conf"
    sed -i 's/^TESTING = "0"/TESTING = "1"/' /etc/csf/csf.conf
fi

# Install Profiles (Priority to 'profiles' folder, fallback to root)
if [ -d "profiles" ]; then
    cp -af profiles/*.conf /usr/local/csf/profiles/ 2>/dev/null
    cp -af profiles/*.conf /etc/csf/ 2>/dev/null
else
    cp -af protection_*.conf /etc/csf/ 2>/dev/null
    cp -af block_all_*.conf /etc/csf/ 2>/dev/null
    cp -af disable_alerts.conf /etc/csf/ 2>/dev/null
fi

# Blocklists & Supporting Files
find_install "csf.blocklists" "/etc/csf/csf.blocklists"
find_install "csf.rbls" "/etc/csf/csf.rbls"
find_install "csf.rblconf" "/etc/csf/csf.rblconf"
find_install "csf.resellers" "/etc/csf/csf.resellers"
[ ! -f "/etc/csf/csf.resellers" ] && touch /etc/csf/csf.resellers
find_install "sanity.txt" "/etc/csf/sanity.txt"
echo " done"

# --- 6. Install UI & Generate Keys ---
echo -n "Installing UI components..."
if [ -d "ui" ]; then
    cp -af ui/* /etc/csf/ui/
fi

# Run the Titanium Key Generator (Smart Mode)
if [ -f "make_ui_cert.sh" ]; then
    echo ""
    sh make_ui_cert.sh
    if [ -f "ui/server.crt" ]; then
        cp -af ui/server.crt /etc/csf/ui/
        cp -af ui/server.key /etc/csf/ui/
        chmod 600 /etc/csf/ui/server.key
    fi
    echo -n "Resuming..."
fi

if [ -d "messenger" ]; then
    cp -af messenger/* /usr/local/csf/tpl/
fi
echo " done"

# --- 7. Control Panel Integration (cPanel Fix) ---

# cPanel
if [ -d "/usr/local/cpanel" ]; then
    echo -n "Detected cPanel... Installing WHM plugin..."
    
    # Determine source folder for cPanel files
    CP_SRC="."
    if [ -d "cpanel" ]; then CP_SRC="cpanel"; fi
    
    mkdir -p /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf
    
    # Install CGI (The Menu)
    cp -af $CP_SRC/csf.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/
    chmod 700 /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
    
    # Install Config
    cp -af $CP_SRC/csf.conf /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf/
    
    # Install Drivers
    if [ -d "/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver" ]; then
        mkdir -p /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
        # Look for driver in root OR cpanel/Driver folder
        if [ -f "$CP_SRC/Driver/ConfigServercsf.pm" ]; then
            cp -af $CP_SRC/Driver/ConfigServercsf.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/
            cp -af $CP_SRC/Driver/ConfigServercsf/META.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf/
        else
            # Fallback to root
            cp -af ConfigServercsf.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ 2>/dev/null
            cp -af META.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf/ 2>/dev/null
        fi
    fi
    
    # Register App
if [ -e "/usr/local/cpanel/bin/register_appconfig" ]; then
    # 1. ALWAYS unregister first to clear corrupted WHM cache
    /usr/local/cpanel/bin/unregister_appconfig csf >/dev/null 2>&1
    
    # 2. Re-register a fresh copy
    /usr/local/cpanel/bin/register_appconfig cpanel/csf.conf
fi
    echo " done"
fi

# DirectAdmin
if [ -d "/usr/local/directadmin" ]; then
    echo -n "Detected DirectAdmin... Installing plugin..."
    mkdir -p /usr/local/directadmin/plugins/csf/scripts
    mkdir -p /usr/local/directadmin/plugins/csf/exec
    
    DA_SRC="."
    if [ -d "da" ]; then DA_SRC="da"; fi
    
    cp -af $DA_SRC/* /usr/local/directadmin/plugins/csf/ 2>/dev/null
    chmod 755 /usr/local/directadmin/plugins/csf/scripts/*
    
    # Compile Wrapper
    if [ -f "csf.c" ] && command -v gcc >/dev/null 2>&1; then
         gcc -o /usr/local/directadmin/plugins/csf/index.cgi csf.c
         chmod 4755 /usr/local/directadmin/plugins/csf/index.cgi
         cp -af /usr/local/directadmin/plugins/csf/index.cgi /usr/local/directadmin/plugins/csf/exec/da_csf.cgi
    fi
    echo " done"
fi

# --- 8. Service Registration ---
if [ -d "/etc/systemd/system" ]; then
    echo -n "Registering systemd services..."
    find_install "lfd.service" "/etc/systemd/system/lfd.service"
    find_install "csf.service" "/etc/systemd/system/csf.service"
    
    # Register RT Services
    if [ -f "/usr/local/sbin/csf-xdp-loader.sh" ]; then
        cat << EOF > /etc/systemd/system/csf-xdp-loader.service
[Unit]
Description=Revolutionary Technology XDP DDoS Filter Loader
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/csf-xdp-loader.sh start
ExecStop=/usr/local/sbin/csf-xdp-loader.sh stop
[Install]
WantedBy=multi-user.target
EOF
        systemctl enable csf-xdp-loader.service >/dev/null 2>&1
    fi
    
    systemctl daemon-reload
    systemctl enable csf.service >/dev/null 2>&1
    systemctl enable lfd.service >/dev/null 2>&1
    echo " done"
else
    echo -n "Registering init.d services..."
    find_install "lfd.sh" "/etc/init.d/lfd"
    find_install "csf.sh" "/etc/init.d/csf"
    chmod 755 /etc/init.d/csf
    chmod 755 /etc/init.d/lfd
    if [ -x "/sbin/chkconfig" ]; then
        /sbin/chkconfig --add csf
        /sbin/chkconfig --add lfd
    fi
    echo " done"
fi

# --- 9. Register RT Crons ---
if [ -f "/usr/local/sbin/rt-google-ip-updater.pl" ]; then
    echo "$(shuf -i 0-59 -n 1) $(shuf -i 3-5 -n 1) * * * root /usr/local/sbin/rt-google-ip-updater.pl > /dev/null 2>&1" > /etc/cron.d/rt-google-ip-updater
fi
if [ -f "/usr/local/sbin/rt-block-reporter.sh" ]; then
    ln -sf /usr/local/sbin/rt-block-reporter.sh /etc/cron.hourly/rt-block-reporter
fi

# --- 10. Final Permission Fixes ---
chmod 600 /etc/csf/csf.conf
chmod 600 /etc/csf/*.conf
chmod 700 /etc/csf/*.sh 2>/dev/null
chmod 700 /etc/csf/*.pl 2>/dev/null

# --- 11. Hardware Acceleration (Auto-Tune) ---
if [ -x "/usr/local/sbin/csf-autotune.sh" ]; then
    echo ""
    echo "Running Revolutionary Technology Hardware Auto-Tuner..."
    /usr/local/sbin/csf-autotune.sh
fi

# ====================================================================
# UNIVAC AEGIS BRIDGE INTEGRATION HOOK
# ====================================================================
echo "Configuring Univac Aegis Bridge telemetry nodes..."

# 1. Ensure the Aegis log exists so LFD does not fail to start on boot
touch /var/log/aegis_bridge.log
chmod 640 /var/log/aegis_bridge.log

# 2. Inject Aegis Tactical Ports into the live csf.conf
sed -i 's/^TCP_IN = "/TCP_IN = "7400:7500,9999,/' /etc/csf/csf.conf
sed -i 's/^UDP_IN = "/UDP_IN = "7400:7500,/' /etc/csf/csf.conf

# 3. Configure Connection Tracking for Aegis DDS limits
sed -i 's/^CT_LIMIT = .*$/CT_LIMIT = "150"/' /etc/csf/csf.conf
sed -i 's/^CT_PORTS = .*$/CT_PORTS = "7400:7500,9999"/' /etc/csf/csf.conf

# 4. Map CUSTOM1_LOG to Aegis telemetry
sed -i 's|^CUSTOM1_LOG = .*$|CUSTOM1_LOG = "/var/log/aegis_bridge.log"|' /etc/csf/csf.conf

# 5. Inject LFD Regex Rules for Aegis Audits into regex.custom.pm
# We use grep to ensure we don't append it twice on reinstall/upgrade
if ! grep -q "Aegis Shore Audit" /usr/local/csf/bin/regex.custom.pm; then
cat << 'EOF' >> /usr/local/csf/bin/regex.custom.pm

# --- START UNIVAC AEGIS BRIDGE RULES ---
if ($line =~ /Aegis Shore Audit: Unauthorized command sequence from (\d+\.\d+\.\d+\.\d+)/) {
    return ("Aegis Unauthorized Command", $1, "aegis_bridge", "1", "86400");
}

if ($line =~ /TCP Listener: Malformed tactical track payload dropped from (\d+\.\d+\.\d+\.\d+)/) {
    return ("Aegis Malformed Payload", $1, "aegis_bridge", "3", "3600");
}
# --- END UNIVAC AEGIS BRIDGE RULES ---
EOF
fi

echo "Aegis Bridge integrated successfully."
# ====================================================================

echo ""
echo "---------------------------------------------------------------"
echo "Installation Complete."
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "---------------------------------------------------------------"
echo "1. Review configuration: /etc/csf/csf.conf"
echo "2. Restart firewall:     csf -r"
echo "3. Disable Testing Mode when ready."
echo ""
