#!/bin/sh
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.shop
#   @description        Generic Installer for Revolutionary Technology CSF/LFD
#   @copyright          Copyright (C) 2025-2026 Revolutionary Technology
# #

umask 0177

case $0 in
    /*) script="$0" ;;
    *)  script="$(pwd)/$0" ;;
esac
script_dir=$(dirname "$script")

# Include global settings if available
if [ -f "$script_dir/global.sh" ]; then
    . "$script_dir/global.sh"
fi

echo "Installing Revolutionary Technology CSF/LFD (Generic)..."

# --- 1. Root Check ---
if [ ! `id -u` = 0 ]; then
	echo "FAILED: You must be logged in as root (UID:0) to install."
	exit
fi

# --- 2. Create Directories ---
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

# --- 3. Install Dependencies (XDP/BPF + Kernel Headers) ---
echo "Checking/Installing Dependencies..."
if [ -f /usr/bin/yum ]; then
    # RHEL/CentOS/Alma/Rocky
    yum install -y epel-release >/dev/null 2>&1
    yum install -y xtables-addons-kmod xtables-addons openssl mokutil \
                   kernel-devel-$(uname -r) bpftool xdp-tools bpfilter bpfilter-devel gcc make >/dev/null 2>&1
elif [ -f /usr/bin/apt-get ]; then
    # Debian/Ubuntu
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y xtables-addons-common xtables-addons-dkms openssl mokutil \
                       linux-headers-$(uname -r) linux-tools-$(uname -r) linux-tools-common \
                       xdp-tools bpftool bpfilter bpfilter-devel gcc make >/dev/null 2>&1
elif [ -f /usr/bin/zypper ]; then
    # OpenSUSE
    zypper --non-interactive refresh >/dev/null 2>&1
    zypper --non-interactive install kernel-devel bpftool xdp-tools bpfilter bpfilter-devel gcc make >/dev/null 2>&1
fi

# --- 4. Secure Boot & Modules ---
if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state | grep -q "SecureBoot enabled"; then
        echo "    > Secure Boot DETECTED. Running signer..."
        if [ -f "rt-sign-module.sh" ]; then
            chmod 700 rt-sign-module.sh
            ./rt-sign-module.sh
        fi
    fi
fi

# Load Active Defense Module
modprobe xt_ECHO 2>/dev/null

# --- 5. Install Core Files ---
echo "Installing binaries and libraries..."
cp -af install.txt /etc/csf/
cp -af csf.pl /usr/sbin/csf
cp -af lfd.pl /usr/sbin/lfd
cp -af csf-autotune.sh /usr/sbin/csf-autotune
cp -afR lib/* /usr/local/csf/lib/

# Explicitly Install AES Crypto Module
if [ -f "Rijndael_PP.pm" ]; then
    echo "    > Installing AES Encryption Module..."
    mkdir -p /usr/local/csf/lib/Crypt
    cp -af Rijndael_PP.pm /usr/local/csf/lib/Crypt/Rijndael_PP.pm
    chmod 700 /usr/local/csf/lib/Crypt/Rijndael_PP.pm
fi

chmod 700 /usr/sbin/csf
chmod 700 /usr/sbin/lfd
chmod 700 /usr/sbin/csf-autotune
chmod 700 /usr/local/csf/lib/ConfigServer/*

# --- 6. Config & UI ---
if [ ! -f "/etc/csf/csf.conf" ]; then
    cp -af csf.generic.conf /etc/csf/csf.conf
    sed -i 's/^TESTING = "0"/TESTING = "1"/' /etc/csf/csf.conf
fi
cp -af protection_*.conf /etc/csf/
cp -af block_all_*.conf /etc/csf/
cp -af disable_alerts.conf /etc/csf/
cp -af csf.blocklists /etc/csf/
cp -af csf.rbls /etc/csf/
cp -af csf.rblconf /etc/csf/
cp -af csf.resellers /etc/csf/ 2>/dev/null || touch /etc/csf/csf.resellers

# UI & Stunt Mode Keys
echo "Installing UI..."
cp -af ui/* /etc/csf/ui/
if [ -f "make_ui_cert.sh" ]; then
    echo "    > Generating UI SSL Keys (Titanium Mode)..."
    sh make_ui_cert.sh >/dev/null 2>&1
    if [ -f "ui/server.crt" ]; then
        cp -af ui/server.crt /etc/csf/ui/
        cp -af ui/server.key /etc/csf/ui/
        chmod 600 /etc/csf/ui/server.key
    fi
fi
cp -af messenger/* /usr/local/csf/tpl/

# --- 7. Revolutionary Tech Tools (XDP, Google) ---
echo "Installing Active Defense Tools..."

# XDP Shield
if [ -f "csf-xdp-loader.sh" ]; then
    cp "csf-xdp-loader.sh" "/usr/local/sbin/csf-xdp-loader.sh"
    chmod 700 "/usr/local/sbin/csf-xdp-loader.sh"
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
    fi
fi

# Google IP Updater
if [ -f "rt-google-ip-updater.pl" ]; then
    cp "rt-google-ip-updater.pl" "/usr/local/sbin/rt-google-ip-updater.pl"
    chmod 700 "/usr/local/sbin/rt-google-ip-updater.pl"
    echo "$(shuf -i 0-59) $(shuf -i 3-5) * * * root /usr/local/sbin/rt-google-ip-updater.pl > /dev/null 2>&1" > /etc/cron.d/rt-google-ip-updater
fi

# Stress Engine
mkdir -p -m 0755 /usr/local/include/csf/pre.d/
if [ -f "stressengine.sh" ]; then
    cp -avf stressengine.sh /usr/local/include/csf/pre.d/
    chmod 700 /usr/local/include/csf/pre.d/*.sh
fi

# --- 8. ModSec3 Bridge ---
if [ -f "/var/log/modsec_audit.log" ] || [ -f "/var/log/apache2/modsec_audit.log" ] || [ -f "/var/log/httpd/modsec_audit.log" ]; then
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
# Auto-detect standard paths
if (-f "/etc/apache2/logs/modsec_audit.log") { $MODSEC3_LOG = "/etc/apache2/logs/modsec_audit.log"; }
elsif (-f "/var/log/httpd/modsec_audit.log") { $MODSEC3_LOG = "/var/log/httpd/modsec_audit.log"; }
elsif (-f "/var/log/apache2/modsec_audit.log") { $MODSEC3_LOG = "/var/log/apache2/modsec_audit.log"; }
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
        # Update csf.conf to use new log
        sed -i 's#^MODSEC_LOG = ".*"#MODSEC_LOG = "/var/log/modsec_compat.log"#' /etc/csf/csf.conf
        echo "    [OK] ModSec3 Bridge installed."
    fi
fi

# --- 9. Service Registration ---
echo "Registering Services..."
if [ -d "/etc/systemd/system" ]; then
    cp -af lfd.service /etc/systemd/system/
    cp -af csf.service /etc/systemd/system/ 2>/dev/null
    systemctl daemon-reload
    systemctl enable csf.service >/dev/null 2>&1
    systemctl enable lfd.service >/dev/null 2>&1
else
    # Legacy Init
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
fi

# Final Permissions
chmod 600 /etc/csf/csf.conf
chmod 700 /etc/csf/*.sh /etc/csf/*.pl

# Auto-Tune
if [ -x "/usr/sbin/csf-autotune" ]; then
    echo "Running Hardware Auto-Tuner..."
    /usr/sbin/csf-autotune
fi

echo ""
echo "Installation Complete."
echo "Revolutionary Technology - ConfigServer Security & Firewall"
echo "1. Review: /etc/csf/csf.conf"
echo "2. Restart: csf -r"
echo ""