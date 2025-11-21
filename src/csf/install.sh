#!/bin/bash
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.shop
#   @docs               https://docs.configserver.shop
#   @download           https://download.configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Dr. Correo Hofstad
#                       Copyright (C) 2025-2026 Dr. Cory 'Aetherinox' Hofstad Jr.
#                       Copyright (C) 2025-2026 Revolutionary Technology https://revolutionarytechnology.net
#   @license            GPLv3
#   @updated            11.21.2025
# #

# #
#   @script     Universal Installer (Merged)
#   @desc       Installs Core, Panel Drivers, and Revolutionary Technology Tools
# #

# --- Configuration ---
CSF_DIR="/etc/csf"
BIN_DIR="/usr/sbin"
LIB_DIR="/var/lib/csf"
USR_LOCAL="/usr/local/csf"
SANITY_FILE="sanity.txt"

# RT Tool Paths
AUTOTUNE_DEST="/usr/local/sbin/csf-autotune.sh"
GSB_POLLER_DEST="/usr/local/sbin/rt-gsb-poller.sh"
BLOCK_REPORTER_DEST="/usr/local/sbin/rt-block-reporter.sh"
GOOGLE_IP_DEST="/usr/local/sbin/rt-google-ip-updater.pl"
XDP_LOADER_DEST="/usr/local/sbin/csf-xdp-loader.sh"

# Output Colors
bluel='\033[1;34m'
greenl='\033[1;32m'
redl='\033[1;31m'
greyd='\033[1;30m'
end='\033[0m'

echo
echo -e "  ${bluel}Revolutionary Technology${end} - ConfigServer Security & Firewall"
echo -e "  ${greyd}Universal Installer v2.15.08${end}"
echo

# #
#   Function: Install Core Files
#   (Copies binaries, configs, UI, and libraries common to all systems)
# #
install_core() {
    echo -n "    [Core] Installing binaries and libraries..."
    
    # Create Dirs
    mkdir -p "$CSF_DIR" "$LIB_DIR" "$USR_LOCAL/bin" "$USR_LOCAL/lib" "$USR_LOCAL/tpl" "/etc/csf/ui"

    # Copy Core
    cp -af csf.pl "$BIN_DIR/csf"
    cp -af lfd.pl "$BIN_DIR/lfd"
    cp -afR lib/* "$USR_LOCAL/lib/"
    
    # Permissions
    chmod 700 "$BIN_DIR/csf" "$BIN_DIR/lfd"
    chmod 700 "$USR_LOCAL/lib/ConfigServer/"*
    echo " done."

    echo -n "    [Core] Installing configuration..."
    # Configs (No overwrite if exists)
    if [ ! -f "$CSF_DIR/csf.conf" ]; then
        cp -af csf.conf "$CSF_DIR/csf.conf"
        sed -i 's/^TESTING = "0"/TESTING = "1"/' "$CSF_DIR/csf.conf"
    fi
    
    # Profiles & Blocklists (Always overwrite)
    cp -af protection_*.conf "$CSF_DIR/"
    cp -af block_all_*.conf "$CSF_DIR/"
    cp -af disable_alerts.conf "$CSF_DIR/"
    cp -af csf.blocklists "$CSF_DIR/"
    cp -af csf.rbls "$CSF_DIR/"
    cp -af csf.rblconf "$CSF_DIR/"
    cp -af csf.resellers "$CSF_DIR/" 2>/dev/null || touch "$CSF_DIR/csf.resellers"
    echo " done."

    echo -n "    [Core] Installing UI and Keys..."
    cp -af ui/* "$CSF_DIR/ui/"
    # Key Generation logic
    if [ -f "make_ui_cert.sh" ]; then
        sh make_ui_cert.sh >/dev/null 2>&1
        if [ -f "ui/server.crt" ]; then
            cp -af ui/server.crt "$CSF_DIR/ui/"
            cp -af ui/server.key "$CSF_DIR/ui/"
            chmod 600 "$CSF_DIR/ui/server.key"
        fi
    fi
    cp -af messenger/* "$USR_LOCAL/tpl/"
    echo " done."
}

# #
#   Function: ModSec3 Bridge (Revolutionary Tech)
# #
install_modsec3_bridge() {
    echo "    [RT-Tools] Installing ModSec3 Compatibility Bridge..."

    if [ ! -d /run/systemd/system ]; then
        echo "    ${redl}WARNING:${end} systemd not found. Skipping ModSec3 bridge."
        return 1
    fi

    # Create the Perl converter script
    cat << 'EOF' > /usr/local/sbin/modsec3_converter.pl
#!/usr/bin/perl
# ModSecurity 3 to CSF Log Converter
# Copyright (C) 2025 Revolutionary Technology
use strict;
use warnings;
use File::Tail;
use JSON::MaybeXS;
use Fcntl qw(:flock);
use POSIX qw(strftime);

my $MODSEC3_LOG = "/var/log/modsec_audit.json";
my $CSF_COMPAT_LOG = "/var/log/modsec_compat.log";

# Try common paths
if (-f "/etc/apache2/logs/modsec_audit.log") { $MODSEC3_LOG = "/etc/apache2/logs/modsec_audit.log"; }
elsif (-f "/var/log/httpd/modsec_audit.log") { $MODSEC3_LOG = "/var/log/httpd/modsec_audit.log"; }

open(my $out_fh, ">>", $CSF_COMPAT_LOG) or die "Cannot open output: $!";
$out_fh->autoflush(1);

my $json = JSON::MaybeXS->new(utf8 => 1, allow_nonref => 1);
my $file = File::Tail->new(name => $MODSEC3_LOG, maxinterval => 5, adjustafter => 10);

while (defined(my $line = $file->read)) {
    my $data;
    eval { $data = $json->decode($line); };
    if ($@) { next; }
    
    # Simple extraction logic for brevity
    my $ip = $data->{'transaction'}->{'client_ip'};
    my $msgs = $data->{'transaction'}->{'messages'} || [];
    foreach my $msg (@$msgs) {
         my $sev = $msg->{'details'}->{'severity'} // "INFO";
         if ($sev eq "CRITICAL" || $sev eq "ERROR") {
             my $t = strftime("%a %b %d %H:%M:%S %Y", localtime);
             print $out_fh "[$t] [error] [client $ip] ModSecurity: " . ($msg->{'message'} || "") . "\n";
         }
    }
}
EOF
    chmod +x /usr/local/sbin/modsec3_converter.pl

    # Create Systemd Service
    cat << EOF > /etc/systemd/system/modsec3-converter.service
[Unit]
Description=Revolutionary Technology: ModSecurity 3 Converter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/modsec3_converter.pl
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable modsec3-converter.service >/dev/null 2>&1
    echo "    [RT-Tools] ModSec3 Bridge installed."
}

# #
#   Main Logic
# #

# 1. Install Core
install_core

# 2. Panel Detection & Drivers
echo ""
if [ -e "/usr/local/cpanel/version" ]; then
    echo "    [Panel] Detected cPanel. Installing WHM integration..."
    cp -af csf.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/
    cp -af csf.conf /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf/
    if [ -d "/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver" ]; then
        mkdir -p /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
        cp -af ConfigServercsf.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/
        cp -af META.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf/
    fi
    if [ -x "/usr/local/cpanel/bin/register_appconfig" ]; then
        /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf/csf.conf
    fi

elif [ -e "/usr/local/interworx" ]; then
    echo "    [Panel] Detected InterWorx. Installing NodeWorx plugin..."
    mkdir -p /usr/local/interworx/plugins/configservercsf
    cp -af interworx/* /usr/local/interworx/plugins/configservercsf/
    chown -R iworx:iworx /usr/local/interworx/plugins/configservercsf
    chmod 755 /usr/local/interworx/plugins/configservercsf/lib/*.pl

elif [ -e "/usr/local/vesta" ]; then
    echo "    [Panel] Detected VestaCP. Installing integration..."
    if [ -d "/usr/local/vesta/web/list" ]; then
        mkdir -p /usr/local/vesta/web/list/csf
        cp -af vesta/* /usr/local/vesta/web/list/csf/
    fi

elif [ -d "/usr/libexec/webmin" ]; then
    echo "    [Panel] Detected Webmin. Installing module..."
    mkdir -p /usr/libexec/webmin/csf
    cp -af webmin/csf/* /usr/libexec/webmin/csf/
else
    echo "    [Panel] Generic Linux detected. No panel specific drivers installed."
fi

# 3. Service Registration
echo "    [System] Registering services..."
if [ -d "/etc/systemd/system" ]; then
    cp -af lfd.service /etc/systemd/system/
    cp -af csf.service /etc/systemd/system/ 2>/dev/null 
    systemctl daemon-reload
    systemctl enable csf.service >/dev/null 2>&1
    systemctl enable lfd.service >/dev/null 2>&1
else
    cp -af lfd.sh /etc/init.d/lfd
    cp -af csf.sh /etc/init.d/csf
    chmod 755 /etc/init.d/csf /etc/init.d/lfd
    if [ -x "/sbin/chkconfig" ]; then
        /sbin/chkconfig --add csf
        /sbin/chkconfig --add lfd
    elif [ -x "/usr/sbin/update-rc.d" ]; then
        update-rc.d csf defaults
        update-rc.d lfd defaults
    fi
fi

# 4. ModSec Check
if [ -f "/etc/apache2/logs/modsec_audit.log" ] || [ -f "/var/log/modsec_audit.json" ]; then
    install_modsec3_bridge
fi

# 5. RT Hardware Tools
echo ""
echo "    [RT-Tools] Installing Hardware Acceleration..."

# Auto-Tuner
if [ -f "csf-autotune.sh" ]; then
    cp "csf-autotune.sh" "$AUTOTUNE_DEST"
    chmod +x "$AUTOTUNE_DEST"
    echo "    > Running Auto-Tuner (Profile Detection)..."
    $AUTOTUNE_DEST
fi

# Google IP Updater
if [ -f "rt-google-ip-updater.pl" ]; then
    cp "rt-google-ip-updater.pl" "$GOOGLE_IP_DEST"
    chmod +x "$GOOGLE_IP_DEST"
    echo "    > Installed Google IP Updater."
fi

# XDP Shield
if [ -f "csf-xdp-loader.sh" ]; then
    cp "csf-xdp-loader.sh" "$XDP_LOADER_DEST"
    chmod +x "$XDP_LOADER_DEST"
    echo "    > Installed XDP Shield."
fi

echo ""
echo "---------------------------------------------------------------"
echo "Installation Complete."
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "---------------------------------------------------------------"
echo "1. Review configuration: /etc/csf/csf.conf"
echo "2. Restart firewall:     csf -r"
echo ""