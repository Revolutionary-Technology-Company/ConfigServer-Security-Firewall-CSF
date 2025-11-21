#!/bin/sh
###############################################################################
#
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
#   @website            https://configserver.shop
#   @description        VestaCP Installer for Revolutionary Technology CSF/LFD
#
###############################################################################

echo "---------------------------------------------------------------"
echo "Revolutionary Technology - ConfigServer Security & Firewall Installer"
echo "Copyright (C) 2025-2026 Dr. Correo Hofstad"
echo "---------------------------------------------------------------"
echo ""

umask 0177

case $0 in
    /*) script="$0" ;;
    *)  script="$(pwd)/$0" ;;
esac
script_dir=$(dirname "$script")

if [ -f "$script_dir/global.sh" ]; then
    . "$script_dir/global.sh"
fi

# --- 1. Root Check ---
if [ ! `id -u` = 0 ]; then
	echo "FAILED: You must be logged in as root (UID:0) to install."
	exit
fi

# --- 2. Create Directories ---
echo -n "Creating directory structure..."
mkdir -p -m 0600 /etc/csf
mkdir -p -m 0600 /var/lib/csf/backup
mkdir -p -m 0600 /var/lib/csf/Geo
mkdir -p -m 0600 /var/lib/csf/ui
mkdir -p -m 0600 /var/lib/csf/stats
mkdir -p -m 0600 /var/lib/csf/lock
mkdir -p -m 0600 /var/lib/csf/webmin
mkdir -p -m 0600 /var/lib/csf/zone
mkdir -p -m 0600 /usr/local/csf/bin
mkdir -p -m 0600 /usr/local/csf/lib
mkdir -p -m 0600 /usr/local/csf/tpl
mkdir -p -m 0600 /usr/local/csf/bpf
echo " done"

# ==============================================================================
# PHASE 1: ENVIRONMENT SETUP & DEPENDENCIES
# ==============================================================================
echo "Checking and installing Dependencies..."

if [ -f /usr/bin/yum ]; then
    # RHEL/CentOS/Alma (Common for Vesta)
    echo "    > Detected yum (RHEL/CentOS)."
    yum install -y epel-release >/dev/null 2>&1
    yum install -y xtables-addons-kmod xtables-addons openssl mokutil \
                   kernel-devel-$(uname -r) bpftool xdp-tools bpfilter bpfilter-devel gcc make >/dev/null 2>&1

elif [ -f /usr/bin/apt-get ]; then
    # Debian/Ubuntu (Common for Vesta)
    echo "    > Detected apt (Debian/Ubuntu)."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y xtables-addons-common xtables-addons-dkms openssl mokutil \
                       linux-headers-$(uname -r) linux-tools-$(uname -r) linux-tools-common \
                       xdp-tools bpftool bpfilter bpfilter-devel gcc make >/dev/null 2>&1
fi
echo "    > Dependencies installed."

# ==============================================================================
# PHASE 2: IMMEDIATE MITIGATION & HARDENING
# ==============================================================================
echo "Applying Immediate Mitigation..."

# Enable Syncookies
sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
if ! grep -q "net.ipv4.tcp_syncookies" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1

# Drop invalid packets (u32 signatures)
if command -v iptables >/dev/null 2>&1; then
    iptables -A INPUT -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP 2>/dev/null
fi

# ==============================================================================
# PHASE 3: SECURE BOOT & MODULE SIGNING
# ==============================================================================
echo "Checking Secure Boot state..."
if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state | grep -q "SecureBoot enabled"; then
        echo "    > Secure Boot is ENABLED. Running kernel module signer..."
        if [ -f "rt-sign-module.sh" ]; then
            chmod 700 rt-sign-module.sh
            ./rt-sign-module.sh
        fi
    else
        echo "    > Secure Boot disabled/not supported. Skipping signing."
    fi
fi

# Load ECHO Module
modprobe xt_ECHO 2>/dev/null
if lsmod | grep -q xt_ECHO; then
    echo "    [+] xt_ECHO module loaded."
else
    echo "    [-] xt_ECHO not loaded. (XDP Shield will still protect ports)."
fi

# ==============================================================================
# PHASE 4: CORE INSTALLATION
# ==============================================================================
echo -n "Installing core binaries and libraries..."
cp -af install.txt /etc/csf/
cp -af csf.pl /usr/sbin/csf
cp -af lfd.pl /usr/sbin/lfd
cp -af csf-autotune.sh /usr/sbin/csf-autotune
cp -afR lib/* /usr/local/csf/lib/

# Explicitly Install AES Crypto Module
if [ -f "Rijndael_PP.pm" ]; then
    mkdir -p /usr/local/csf/lib/Crypt
    cp -af Rijndael_PP.pm /usr/local/csf/lib/Crypt/Rijndael_PP.pm
    chmod 700 /usr/local/csf/lib/Crypt/Rijndael_PP.pm
fi

chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd
chmod 700 /usr/sbin/csf-autotune
chmod 700 /usr/local/csf/lib/ConfigServer/*
echo " done"

# --- Install Configuration (Vesta Specifics) ---
echo -n "Installing configuration files..."
if [ ! -f "/etc/csf/csf.conf" ]; then
    # Use Vesta specific config default
    cp -af csf.vesta.conf /etc/csf/csf.conf
    sed -i 's/^TESTING = "0"/TESTING = "1"/' /etc/csf/csf.conf
fi
cp -af protection_*.conf /etc/csf/
cp -af block_all_*.conf /etc/csf/
cp -af disable_alerts.conf /etc/csf/
cp -af csf.blocklists /etc/csf/
cp -af csf.rbls /etc/csf/
cp -af csf.rblconf /etc/csf/
cp -af csf.resellers /etc/csf/ 2>/dev/null || touch /etc/csf/csf.resellers

# Copy Vesta-specific ignore files if not present
if [ ! -f "/etc/csf/csf.ignore" ]; then cp -af csf.vesta.ignore /etc/csf/csf.ignore; fi
if [ ! -f "/etc/csf/csf.pignore" ]; then cp -af csf.vesta.pignore /etc/csf/csf.pignore; fi
if [ ! -f "/etc/csf/csf.allow" ]; then cp -af csf.vesta.allow /etc/csf/csf.allow; fi

# Add Google ASNs to allow list
grep -q "ASN:15169" /etc/csf/csf.allow || echo "ASN:15169 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:36040" /etc/csf/csf.allow || echo "ASN:36040 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:43515" /etc/csf/csf.allow || echo "ASN:43515 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:36561" /etc/csf/csf.allow || echo "ASN:36561 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:19527" /etc/csf/csf.allow || echo "ASN:19527 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:139070" /etc/csf/csf.allow || echo "ASN:139070 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:396982" /etc/csf/csf.allow || echo "ASN:396982 # Google ASN" >> /etc/csf/csf.allow

# Copy standard templates
cp -af csf.dirwatch /etc/csf/
cp -af csf.syslogs /etc/csf/
cp -af csf.logfiles /etc/csf/
cp -af csf.logignore /etc/csf/
cp -af csf.rignore /etc/csf/
cp -af csf.fignore /etc/csf/
cp -af csf.signore /etc/csf/
cp -af csf.suignore /etc/csf/
cp -af csf.uidignore /etc/csf/
cp -af csf.mignore /etc/csf/
cp -af csf.sips /etc/csf/
cp -af csf.dyndns /etc/csf/
cp -af csf.syslogusers /etc/csf/
cp -af csf.smtpauth /etc/csf/
cp -af csf.cloudflare /etc/csf/

echo " done"

# --- Install UI Assets ---
echo -n "Installing UI components..."
cp -af ui/* /etc/csf/ui/
if [ -f "make_ui_cert.sh" ]; then
    sh make_ui_cert.sh >/dev/null 2>&1
    if [ -f "ui/server.crt" ]; then
        cp -af ui/server.crt /etc/csf/ui/
        cp -af ui/server.key /etc/csf/ui/
        chmod 600 /etc/csf/ui/server.key
    fi
fi
cp -af messenger/* /usr/local/csf/tpl/
echo " done"

# ==============================================================================
# PHASE 5: VESTA CP INTEGRATION
# ==============================================================================
echo "Integrating with VestaCP..."
if [ -d "/usr/local/vesta/web/list" ]; then
    mkdir -p /usr/local/vesta/web/list/csf
    
    # Copy Vesta Plugin Files
    if [ -d "vesta" ]; then
        cp -af vesta/* /usr/local/vesta/web/list/csf/
    fi
    
    # Set Vesta Permissions
    chown -R admin:admin /usr/local/vesta/web/list/csf
    chmod -R 755 /usr/local/vesta/web/list/csf
    
    # Install Vesta Wrapper
    if [ -f "csf.c" ] && command -v gcc >/dev/null 2>&1; then
         gcc -o /usr/local/vesta/web/list/csf/index.cgi csf.c
         chmod 4755 /usr/local/vesta/web/list/csf/index.cgi
    fi

    echo "    [OK] Vesta UI installed."
else
    echo "    [WARN] VestaCP web directory not found. Skipping UI integration."
fi

# Run Vesta Auto-Configuration
if [ -f "auto.vesta.pl" ]; then
    chmod 700 auto.vesta.pl
    # Get old version if exists
    OLDVERSION=0
    if [ -e "/etc/csf/version.txt" ]; then OLDVERSION=`head -n 1 /etc/csf/version.txt`; fi
    ./auto.vesta.pl $OLDVERSION
fi
echo " done"

# ==============================================================================
# PHASE 6: REVOLUTIONARY TECHNOLOGY TOOLS
# ==============================================================================
echo "Installing Revolutionary Technology Tools..."

# 1. Stress Engine
mkdir -p -m 0755 /usr/local/include/csf/pre.d/
if [ -f "stressengine.sh" ]; then
    cp -avf stressengine.sh /usr/local/include/csf/pre.d/
    cp -avf stressengine.sh /usr/local/sbin/stressengine.sh
    chmod 700 /usr/local/include/csf/pre.d/*.sh
    chmod 700 /usr/local/sbin/stressengine.sh
    echo "    [OK] Stress Engine installed."
fi

# 2. XDP Shield Loader
if [ -f "csf-xdp-loader.sh" ]; then
    cp "csf-xdp-loader.sh" "/usr/local/sbin/csf-xdp-loader.sh"
    chmod 700 "/usr/local/sbin/csf-xdp-loader.sh"
    
    # Create Systemd Service
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
        systemctl daemon-reload
        systemctl enable csf-xdp-loader.service >/dev/null 2>&1
        echo "    [OK] XDP Shield Service installed."
    fi
fi

# 3. Google IP Updater
if [ -f "rt-google-ip-updater.pl" ]; then
    cp "rt-google-ip-updater.pl" "/usr/local/sbin/rt-google-ip-updater.pl"
    chmod 700 "/usr/local/sbin/rt-google-ip-updater.pl"
    # Create Cron
    echo "$(shuf -i 0-59) $(shuf -i 3-5) * * * root /usr/local/sbin/rt-google-ip-updater.pl > /dev/null 2>&1" > /etc/cron.d/rt-google-ip-updater
    echo "    [OK] Google IP Updater installed."
fi

# 4. ModSec3 Bridge
if [ -f "/var/log/modsec_audit.log" ] || [ -f "/var/log/httpd/modsec_audit.log" ]; then
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
if (-f "/var/log/httpd/modsec_audit.log") { $MODSEC3_LOG = "/var/log/httpd/modsec_audit.log"; }
elsif (-f "/var/log/modsec_audit.log") { $MODSEC3_LOG = "/var/log/modsec_audit.log"; }
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
    
    # Service
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
    # Update csf.conf to use new log
    sed -i 's#^MODSEC_LOG = ".*"#MODSEC_LOG = "/var/log/modsec_compat.log"#' /etc/csf/csf.conf
    echo "    [OK] ModSec3 Bridge installed."
fi

# ==============================================================================
# PHASE 7: FINALIZATION (Service Registration)
# ==============================================================================

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

# Permissions
chmod 600 /etc/csf/csf.conf
chmod 700 /etc/csf/*.sh /etc/csf/*.pl

# Hardware Auto-Tune
if [ -x "/usr/sbin/csf-autotune" ]; then
    echo ""
    echo "Running Hardware Auto-Tuner..."
    /usr/sbin/csf-autotune
fi

echo ""
echo "Installation Complete."
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "---------------------------------------------------------------"
echo "1. Review configuration: /etc/csf/csf.conf"
echo "2. Restart firewall:     csf -r"
echo "3. Disable Testing Mode when ready."
echo ""