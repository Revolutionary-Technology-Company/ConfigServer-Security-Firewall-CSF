#!/bin/sh
###############################################################################
#
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @website            https://configserver.shop
#   @description        Universal Installer for Revolutionary Technology CSF/LFD
#
###############################################################################

echo "---------------------------------------------------------------"
echo "Revolutionary Technology - ConfigServer Security & Firewall Installer"
echo "Copyright (C) 2025-2026 Dr. Correo Hofstad"
echo "---------------------------------------------------------------"
echo ""

# --- 1. Directory Setup ---
echo -n "Creating directory structure..."
if [ ! -d "/etc/csf" ]; then mkdir -p /etc/csf; fi
if [ ! -d "/var/lib/csf" ]; then mkdir -p /var/lib/csf; fi
if [ ! -d "/usr/local/csf" ]; then mkdir -p /usr/local/csf; fi
if [ ! -d "/usr/local/csf/bin" ]; then mkdir -p /usr/local/csf/bin; fi
if [ ! -d "/usr/local/csf/lib" ]; then mkdir -p /usr/local/csf/lib; fi
if [ ! -d "/usr/local/csf/tpl" ]; then mkdir -p /usr/local/csf/tpl; fi
echo " done"

# --- 2. Copy Core Files ---
echo -n "Installing core binaries and libraries..."
cp -af csf.pl /usr/sbin/csf
cp -af lfd.pl /usr/sbin/lfd
cp -af csf-autotune.sh /usr/sbin/csf-autotune
cp -afR lib/* /usr/local/csf/lib/
chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd
chmod 700 /usr/sbin/csf-autotune
chmod 700 /usr/local/csf/lib/ConfigServer/*
echo " done"

# --- 3. Install Configuration & Blocklists ---
echo -n "Installing configuration files..."
# Only copy config if it doesn't exist to prevent overwriting user settings
if [ ! -f "/etc/csf/csf.conf" ]; then
    cp -af csf.conf /etc/csf/csf.conf
    # Default to testing mode on fresh install
    sed -i 's/^TESTING = "0"/TESTING = "1"/' /etc/csf/csf.conf
fi

# Copy configuration profiles
cp -af protection_*.conf /etc/csf/
cp -af block_all_*.conf /etc/csf/
cp -af disable_alerts.conf /etc/csf/

# Copy Blocklists and RBLs (Always update these on install)
cp -af csf.blocklists /etc/csf/
cp -af csf.rbls /etc/csf/
cp -af csf.rblconf /etc/csf/
cp -af csf.resellers /etc/csf/ 2>/dev/null || touch /etc/csf/csf.resellers
echo " done"

# --- 4. Install UI Assets ---
echo -n "Installing UI components..."
# UI Assets
if [ ! -d "/etc/csf/ui" ]; then mkdir -p /etc/csf/ui; fi
cp -af ui/* /etc/csf/ui/
# Generate fresh SSL keys if they don't exist
if [ -f "make_ui_cert.sh" ]; then
    sh make_ui_cert.sh >/dev/null 2>&1
    if [ -f "ui/server.crt" ]; then
        cp -af ui/server.crt /etc/csf/ui/
        cp -af ui/server.key /etc/csf/ui/
        chmod 600 /etc/csf/ui/server.key
    fi
fi
# Messenger Templates
cp -af messenger/* /usr/local/csf/tpl/
echo " done"

# --- 5. Control Panel Integration ---

# cPanel
if [ -d "/usr/local/cpanel" ]; then
    echo -n "Detected cPanel... Installing WHM plugin..."
    cp -af csf.cgi /usr/local/cpanel/whostmgr/docroot/cgi/configserver/
    cp -af csf.conf /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf/
    # Install Drivers
    if [ -d "/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver" ]; then
        mkdir -p /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf
        cp -af ConfigServercsf.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/
        cp -af META.pm /usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/ConfigServercsf/
    fi
    # Register App
    if [ -x "/usr/local/cpanel/bin/register_appconfig" ]; then
        /usr/local/cpanel/bin/register_appconfig /usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf/csf.conf
    fi
    echo " done"
fi

# DirectAdmin
if [ -d "/usr/local/directadmin" ]; then
    echo -n "Detected DirectAdmin... Installing plugin..."
    if [ -d "/usr/local/directadmin/plugins" ]; then
        mkdir -p /usr/local/directadmin/plugins/csf/scripts
        mkdir -p /usr/local/directadmin/plugins/csf/exec
        cp -af directadmin/* /usr/local/directadmin/plugins/csf/
        chmod 755 /usr/local/directadmin/plugins/csf/scripts/*
        
        # Compile C wrapper if gcc is available
        if [ -f "csf.c" ] && command -v gcc >/dev/null 2>&1; then
             gcc -o /usr/local/directadmin/plugins/csf/index.cgi csf.c
             chmod 4755 /usr/local/directadmin/plugins/csf/index.cgi
             cp -af /usr/local/directadmin/plugins/csf/index.cgi /usr/local/directadmin/plugins/csf/exec/da_csf.cgi
        fi
    fi
    echo " done"
fi

# Webmin
if [ -d "/usr/libexec/webmin" ] || [ -d "/usr/share/webmin" ]; then
    echo -n "Detected Webmin... Installing module..."
    # Assuming standard webmin install path
    WEBMIN_DIR="/usr/libexec/webmin"
    if [ -d "/usr/share/webmin" ]; then WEBMIN_DIR="/usr/share/webmin"; fi
    
    mkdir -p $WEBMIN_DIR/csf
    cp -af webmin/csf/* $WEBMIN_DIR/csf/
    echo " done"
fi

# InterWorx
if [ -d "/usr/local/interworx" ]; then
    echo -n "Detected InterWorx... Installing plugin..."
    mkdir -p /usr/local/interworx/plugins/configservercsf
    cp -af interworx/* /usr/local/interworx/plugins/configservercsf/
    # Fix Permissions
    chown -R iworx:iworx /usr/local/interworx/plugins/configservercsf
    chmod 755 /usr/local/interworx/plugins/configservercsf/lib/*.pl
    echo " done"
fi

# VestaCP
if [ -d "/usr/local/vesta" ]; then
    echo -n "Detected VestaCP... Installing plugin..."
    if [ -d "/usr/local/vesta/web/list" ]; then
        mkdir -p /usr/local/vesta/web/list/csf
        cp -af vesta/* /usr/local/vesta/web/list/csf/
    fi
    echo " done"
fi

# --- 6. RT Tools & ModSec3 Integration ---

# Google IP Updater
if [ -f "rt-google-ip-updater.pl" ]; then
    cp "rt-google-ip-updater.pl" "/usr/local/sbin/rt-google-ip-updater.pl"
    chmod 700 "/usr/local/sbin/rt-google-ip-updater.pl"
    # Create daily cron
    echo "$(shuf -i 0-59) $(shuf -i 3-5) * * * root /usr/local/sbin/rt-google-ip-updater.pl > /dev/null 2>&1" > /etc/cron.d/rt-google-ip-updater
fi

# XDP Shield Loader
if [ -f "csf-xdp-loader.sh" ]; then
    cp "csf-xdp-loader.sh" "/usr/local/sbin/csf-xdp-loader.sh"
    chmod 700 "/usr/local/sbin/csf-xdp-loader.sh"
    # Register service if systemd present
    if [ -d "/etc/systemd/system" ]; then
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
fi

# ModSec3 Bridge (Only if ModSec3 log detected)
if [ -f "/etc/apache2/logs/modsec_audit.log" ] || [ -f "/var/log/modsec_audit.json" ]; then
    echo "Generating ModSec3 Converter Bridge..."
    cat << 'EOF' > /usr/local/sbin/modsec3_converter.pl
#!/usr/bin/perl
use strict;
use warnings;
use File::Tail;
use JSON::MaybeXS;
use Fcntl qw(:flock);
use POSIX qw(strftime);
my $MODSEC3_LOG = "/var/log/modsec_audit.json";
my $CSF_COMPAT_LOG = "/var/log/modsec_compat.log";
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
    chmod 700 /usr/local/sbin/modsec3_converter.pl
    
    if [ -d "/etc/systemd/system" ]; then
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
        systemctl enable modsec3-converter.service >/dev/null 2>&1
    fi
fi

# --- 7. Service Registration (Systemd) ---
if [ -d "/etc/systemd/system" ]; then
    echo -n "Registering systemd services..."
    cp -af lfd.service /etc/systemd/system/
    cp -af csf.service /etc/systemd/system/ 2>/dev/null
    systemctl daemon-reload
    systemctl enable csf.service >/dev/null 2>&1
    systemctl enable lfd.service >/dev/null 2>&1
    echo " done"
else
    # Fallback for init.d
    echo -n "Registering init.d services..."
    cp -af lfd.sh /etc/init.d/lfd
    cp -af csf.sh /etc/init.d/csf
    chmod 755 /etc/init.d/csf
    chmod 755 /etc/init.d/lfd
    if [ -x "/sbin/chkconfig" ]; then
        /sbin/chkconfig --add csf
        /sbin/chkconfig --add lfd
    elif [ -x "/usr/sbin/update-rc.d" ]; then
        update-rc.d csf defaults
        update-rc.d lfd defaults
    fi
    echo " done"
fi

# --- 8. Final Permission Fixes ---
chmod 600 /etc/csf/csf.conf
chmod 600 /etc/csf/*.conf
chmod 700 /etc/csf/*.sh
chmod 700 /etc/csf/*.pl

# --- 9. Hardware Acceleration (Auto-Tune) ---
if [ -x "/usr/sbin/csf-autotune" ]; then
    echo ""
    echo "Running Revolutionary Technology Hardware Auto-Tuner..."
    /usr/sbin/csf-autotune
fi

echo ""
echo "---------------------------------------------------------------"
echo "Installation Complete."
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "---------------------------------------------------------------"
echo "1. Review configuration: /etc/csf/csf.conf"
echo "2. Restart firewall:     csf -r"
echo "3. Disable Testing Mode when ready."
echo ""