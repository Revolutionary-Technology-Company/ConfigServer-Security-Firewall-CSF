#!/bin/sh
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.shop
#   @docs               https://docs.configserver.shop
#   @download           https://download.configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Dr. Correo Hofstad
#                       Copyright (C) 2025-2026 Dr. Cory 'Aetherinox' Hofstad Jr.
#                       Copyright (C) 2025-2026 Revolutionary Technology Revolutionarytechnology.net
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            11.15.2025
# #

# #
#   @script     ConfigServer Security & Firewall Installer
#   @desc       determines the users distro and (if any) control panel, launches correct installer sub-script
#
#   @usage      Normal install          sh install.sh
#               Dryrun install          sh install.sh --dryrun
# #

# #
#	Allow for execution from different relative directories
# #

case $0 in
    /*) script="$0" ;;                       # Absolute path
    *)  script="$(pwd)/$0" ;;                # Relative path
esac

# #
#	Find script directory
# #

script_dir=$(dirname "$script")

# #
#   Include global
# #

. "$script_dir/global.sh" ||
{
    echo "    Error: cannot source $script_dir/global.sh. Aborting." >&2
    exit 1
}

# #
#    Change working directory
# #

cd "$script_dir" || exit 1

# #
#   Define › Args
# #

argDryrun="false"				# runs the logic but doesn't actually install; no changes
argDetect="false"				# returns the installer name + desc that would have ran, but exits; no changes
argLegacy="false"				# certain actions will work how pre CSF v15.01 did 

# #
#   Define directories
#   (Moved definitions here for clarity)
# #
CSF_DIR="/etc/csf"
BIN_DIR="/usr/sbin"
LIB_DIR="/var/lib/csf"
SANITY_FILE="sanity.txt"

# --- [NEW] Define ALL RT script paths ---
AUTOTUNE_SCRIPT="csf-autotune.sh"
AUTOTUNE_DEST="/usr/local/sbin/csf-autotune.sh"

FIRMWARE_CHECK_SCRIPT="csf-firmware-check.sh"
FIRMWARE_CHECK_DEST="/usr/local/sbin/csf-firmware-check.sh"

GSB_POLLER_SCRIPT="rt-gsb-poller.sh"
GSB_POLLER_DEST="/usr/local/sbin/rt-gsb-poller.sh"
GSB_SERVICE_FILE="/etc/systemd/system/rt-gsb-poller.service"

BLOCK_REPORTER_SCRIPT="rt-block-reporter.sh"
BLOCK_REPORTER_DEST="/usr/local/sbin/rt-block-reporter.sh"
BLOCK_REPORTER_CRON="/etc/cron.hourly/rt-block-reporter"

STRESS_ENGINE_SCRIPT="stressengine.sh"
STRESS_ENGINE_DEST="/usr/local/sbin/stressengine.sh"

SIGN_MODULE_SCRIPT="rt-sign-module.sh"
SIGN_MODULE_DEST="/usr/local/sbin/rt-sign-module.sh"

UPDATE_SCRIPT="rt-csf-update.sh"
UPDATE_DEST="/usr/local/sbin/rt-csf-update.sh"

# --- [UPDATED] Google IP Updater ---
GOOGLE_IP_SCRIPT="rt-google-ip-updater.pl"
GOOGLE_IP_DEST="/usr/local/sbin/rt-google-ip-updater.pl"
GOOGLE_IP_CRON="/etc/cron.d/rt-google-ip-updater"
# --- [END UPDATED] ---


# #
#   Func › Usage Menu
# #

opt_usage( )
{
    echo
    printf "  ${bluel}${APP_NAME}${end}\n" 1>&2
    printf "  ${greym}${APP_DESC}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$APP_VERSION${end}\n" 1>&2
    printf "  ${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}--detect${greyd} | ${greym}--dryrun${greyd} |  ${greym}--version${greyd} | ${greym}--help ${greyd}]${end}" 1>&2
    echo
    echo
    printf '  %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Flags${end}             " "" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " " ${white}required flag" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " " ${white}required flag; multiple flags can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " " ${white}optional flag" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " " ${white}optional flag; multiple flags can be specified" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " " ${white}one flag or the other; do not use both" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Arguments${end}         " "${fuchsiad}$app_file_this${end} ${greyd}[ ${greym}-d${yellowd} arg${greyd} | ${greym}--flag ${yellowd}arg${greyd} ]${end}${yellowd} arg${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${fuchsiad}$app_file_this${end} ${greym}--detect${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--version${yellowd} ${end}" 1>&2
    printf '  %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${fuchsiad}$app_file_this${end} ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${end}" 1>&2
    echo
    printf '  %-5s %-40s\n' "${greyd}Flags:${end}" "" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --detect ${yellowd}${end}                     " "returns installer script that will run; does not install csf ${navy}<default> ${peach}${argDetect:-"disabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dryrun ${yellowd}${end}                     " "simulates installation, does not install csf ${navy}<default> ${peach}${argDryrun:-"disabled"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${navy}<current> ${peach}${APP_VERSION:-"unknown"} ${end}" 1>&2
    printf '  %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    echo
}

# #
#   Args › Parse
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dryrun)
            argDryrun="true"
            ;;
        -D|--detect)
            argDetect="true"
            ;;
        -l|--legacy)
            argLegacy="true"
            ;;
        -v|--ver|--version)
			echo
			print "    ${blued}${bold}${APP_NAME}${end} - v$APP_VERSION "
			print "    ${greenl}${bold}${APP_REPO} "
			echo
            exit 1
            ;;
        -h|--help|\?)
            opt_usage
            exit 1
            ;;
        *)

			error "    ❌ Unknown flag ${redl}$1${greym}. Aborting."
			exit 1
			;;
    esac
    shift
done

# #
#	Runs the requested installer
#	
#	@arg 			installerFile				Install script to run
#	@arg 			installerDesc				Brief description for the user
#	@usage			run_installer "install.cpanel.sh" "csf cPanel installer"
# #

run_installer()
{
    installer="$1"
    description="$2"

	# #
	#	Detect; but do not run
	# #

    if [ "$argDetect" = "true" ]; then
		ok "    Detected Installer: ${greenl}$script_dir/$installer${greym} ($description) "
		exit 0
	fi

	# #
	#	Dryrun; or run chosen installer script
	# #

    if [ "$argDryrun" = "true" ]; then
		ok "    Dryrun flag specified; skipped installer ${greenl}$script_dir/$installer${greym} "
    else

		print
		print "   ${greyd}# #"
		print "   ${greyd}#  ${bluel}${APP_NAME} › Installer${end}" 1>&2
		print "   ${greyd}#  ${greyd}version:${end} ${greyd}$APP_VERSION${end}" 1>&2
		print "   ${greyd}# #"
		print
		ok "    Starting installer ${greenl}$description${greym} › ${greenl}$installer"
		print
	
        sh "$script_dir/$installer"
    fi
}

#####################################################################
# START Revolutionary Technology ModSec3 Bridge Installation
#####################################################################

install_modsec3_bridge() {
    print "    Installing Revolutionary Technology: ModSec3 Compatibility Bridge..."

    # Check for systemd
    if [ ! -d /run/systemd/system ]; then
        print "    ${redl}WARNING:${greym} systemd not found. This bridge requires systemd."
        print "    Skipping ModSec3 bridge installation."
        return 1
    fi

    # --- [UPDATED] Added LWP::Simple for Google IP Updater ---
    print "    > Installing Perl dependencies (JSON::MaybeXS, File::Tail, LWP::Simple)..."
    (cpan install JSON::MaybeXS File::Tail LWP::Simple > /dev/null 2>&1) &

    # --- Create the Perl converter script ---
    print "    > Creating /usr/local/sbin/modsec3_converter.pl..."
    cat << 'EOF' > /usr/local/sbin/modsec3_converter.pl
#!/usr/bin/perl

# 
# ModSecurity 3 to CSF (ModSec2-style) Log Converter
# by Revolutionary Technology
#
# This script reads a ModSec3 JSON log, parses it, and writes
# a new log file in a format that CSF's lfd daemon can understand.
#

use strict;
use warnings;
use File::Tail;
use JSON::MaybeXS;
use Fcntl qw(:flock); # For file locking
use POSIX qw(strftime);

# --- Configuration ---
my $MODSEC3_LOG = "/var/log/modsec_audit.json"; # Default path
my $CSF_COMPAT_LOG = "/var/log/modsec_compat.log";
my %severity_map = (
    "EMERGENCY" => 0, "ALERT"     => 1, "CRITICAL"  => 2,
    "ERROR"     => 3, "WARNING"   => 4, "NOTICE"    => 5,
    "INFO"      => 6, "DEBUG"     => 7
);
my $MIN_SEVERITY_LEVEL = 2; # Block on CRITICAL (2) or higher
# --- End Configuration ---

# Allow custom ModSec3 log path
if ($ARGV[0]) {
    $MODSEC_LOG = $ARGV[0];
}

# Ensure log files exist
unless (-f $MODSEC3_LOG) {
    # Try cPanel path
    if (-f "/etc/apache2/logs/modsec_audit.log") {
        $MODSEC3_LOG = "/etc/apache2/logs/modsec_audit.log";
    } else {
        # Try a few other common paths
        if (-f "/var/log/httpd/modsec_audit.log") {
             $MODSEC3_LOG = "/var/log/httpd/modsec_audit.log";
        } elsif (-f "/var/log/apache2/modsec_audit.log") {
             $MODSEC3_LOG = "/var/log/apache2/modsec_audit.log";
        } else {
             die "FATAL: ModSec3 log not found at $MODSEC3_LOG or other common paths.";
        }
    }
}
open(my $out_fh, ">>", $CSF_COMPAT_LOG) 
    or die "FATAL: Cannot open $CSF_COMPAT_LOG for writing: $!";
$out_fh->autoflush(1);

my $json = JSON::MaybeXS->new(utf8 => 1, allow_nonref => 1);
my $file = File::Tail->new(
    name        => $MODSEC3_LOG,
    maxinterval => 5,
    adjustafter => 10,
    reset_tail  => 0,
);

print "Starting ModSec3-to-CSF Converter...\n";
print "Watching: $MODSEC3_LOG\n";
print "Writing to: $CSF_COMPAT_LOG\n";

while (defined(my $line = $file->read)) {
    my $data;
    eval { $data = $json->decode($line); };
    if ($@) { next; }

    my $client_ip = $data->{'transaction'}->{'client_ip'} || "0.0.0.0";
    my $messages  = $data->{'transaction'}->{'messages'}  || [];
    my $best_severity = 99;
    my $block_message = "";

    foreach my $msg (@$messages) {
        my $severity_name = $msg->{'details'}->{'severity'} || "INFO";
        my $severity_num  = $severity_map{$severity_name} // 99;
        
        if ($severity_num < $best_severity) {
            $best_severity = $severity_num;
            $block_message = $msg->{'message'} || "No message";
        }
    }

    if ($best_severity <= $MIN_SEVERITY_LEVEL) {
        my $time_str = strftime("%a %b %d %H:%%M:%S %Y", localtime);
        my $log_entry = "[$time_str] [security_alert] [client $client_ip] " .
                        "ModSecurity: $block_message [severity $best_severity]\n";
        
        flock($out_fh, LOCK_EX);
        print $out_fh $log_entry;
        flock($out_fh, LOCK_UN);
    }
}
close($out_fh);
EOF

    # Make it executable
    chmod +x /usr/local/sbin/modsec3_converter.pl

    # --- Create the systemd service file ---
    print "    > Creating /etc/systemd/system/modsec3-converter.service..."
    cat << EOF > /etc/systemd/system/modsec3-converter.service
[Unit]
Description=Revolutionary Technology: ModSecurity 3 to CSF Converter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/modsec3_converter.pl
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    # --- Enable and start the service ---
    print "    > Enabling and starting converter service..."
    systemctl daemon-reload
    systemctl enable modsec3-converter.service > /dev/null 2>&1
    systemctl restart modsec3-converter.service
    
    print "    ${greenl}ModSec3 Bridge installed successfully."
}

#####################################################################
# END Revolutionary Technology ModSec3 Bridge Installation
#####################################################################
#
# --- [Revolutionary Tech] ModSecurity Log Detection ---
#
print ""
print "    Detecting ModSecurity configuration..."

# This variable will be exported for sub-installers to use
MODSEC_LOG_PATH=""

# Logic to detect ModSec3 (e.g., cPanel's ea-modsec30)
if [ -f "/etc/apache2/logs/modsec_audit.log" ] || \
   [ -f "/var/log/modsec_audit.json" ] || \
   [ -f "/var/log/httpd/modsec_audit.log" ] || \
   [ -f "/var/log/apache2/modsec_audit.log" ]; then
    
    print "    ModSecurity 3 detected."
    # Run the installer function
    install_modsec3_bridge
    
    # Set the log path for CSF to use our new converter
    MODSEC_LOG_PATH="/var/log/modsec_compat.log"

else
    print "    ModSecurity 3 not found. Checking for ModSec2..."
    # Standard ModSec2 log paths
    if [ -f "/usr/local/apache/logs/modsec_audit.log" ]; then
        MODSEC_LOG_PATH="/usr/local/apache/logs/modsec_audit.log"
    elif [ -f "/var/log/modsec_audit.log" ]; then
        MODSEC_LOG_PATH="/var/log/modsec_audit.log"
    else
        print "    No standard ModSecurity log found. Leaving default."
        MODSEC_LOG_PATH="/var/log/modsec_audit.log"
    fi
fi

# EXPORT the variable so the sub-shell (run_installer) can read it
export MODSEC_LOG_PATH
print "    Setting MODSEC_LOG path to: ${greenl}$MODSEC_LOG_PATH"
# #
#   Define which installation script to run
# #

if [ -e "/usr/local/cpanel/version" ]; then
    run_installer "install.cpanel.sh" "cPanel"
elif [ -e "/usr/local/directadmin/directadmin" ]; then
    run_installer "install.directadmin.sh" "DirectAdmin"
elif [ -e "/usr/local/interworx" ]; then
    run_installer "install.interworx.sh" "InterWorx"
elif [ -e "/usr/local/cwpsrv" ]; then
    run_installer "install.cwp.sh" "CentOS Web Panel (CWP)"
elif [ -e "/usr/local/vesta" ]; then
    run_installer "install.vesta.sh" "VestaCP"
elif [ -e "/usr/local/CyberCP" ]; then
    run_installer "install.cyberpanel.sh" "CyberPanel"
else
    run_installer "install.generic.sh" "Generic"
fi

# -------------------------------------------------------------------
#  BEGIN AUTO-TUNER & TOOLS INTEGRATION
# -------------------------------------------------------------------

print ""
print "    Installing CSF Hardware Acceleration Tools..."

# Check that the sub-installer did its job
if [ ! -f "$CSF_DIR/csf.conf" ]; then
    print "    ${redl}[ERROR]${greym} $CSF_DIR/csf.conf not found. Auto-Tuner cannot run."
elif [ ! -f "$CSF_DIR/$SANITY_FILE" ]; then
    print "    ${redl}[ERROR]${greym} $CSF_DIR/$SANITY_FILE not found. Auto-Tuner cannot run."
else
    # --- Install Auto-Tuner ---
    if [ ! -f "$AUTOTUNE_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $AUTOTUNE_SCRIPT not found in installer directory. Skipping auto-tuning."
    else
        cp "$AUTOTUNE_SCRIPT" "$AUTOTUNE_DEST"
        if [ $? -eq 0 ]; then
            chmod +x "$AUTOTUNE_DEST"
            print "    [OK] Auto-Tuner installed to $AUTOTUNE_DEST"
            
            print ""
            print "    Running initial hardware-based tuning..."
            print "    This will apply the 'Max Performance' 12% resource slice if a high-end server is detected."
            
            "$AUTOTUNE_DEST"
            
            print "    [OK] Initial tuning complete."
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $AUTOTUNE_SCRIPT to $AUTOTUNE_DEST. Skipping auto-tuning."
        fi
    fi
    
    # --- Install Firmware Checker ---
    if [ ! -f "$FIRMWARE_CHECK_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $FIRMWARE_CHECK_SCRIPT not found. Skipping."
    else
        cp "$FIRMWARE_CHECK_SCRIPT" "$FIRMWARE_CHECK_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$FIRMWARE_CHECK_DEST"
            print "    [OK] Hardware Firmware Checker installed to $FIRMWARE_CHECK_DEST"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $FIRMWARE_CHECK_SCRIPT."
        fi
    fi

    # --- [NEW] Install Stress Engine ---
    if [ ! -f "$STRESS_ENGINE_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $STRESS_ENGINE_SCRIPT not found. Skipping."
    else
        cp "$STRESS_ENGINE_SCRIPT" "$STRESS_ENGINE_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$STRESS_ENGINE_DEST"
            print "    [OK] Attacker Stress Engine installed to $STRESS_ENGINE_DEST"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $STRESS_ENGINE_SCRIPT."
        fi
    fi

    # --- [NEW] Install Secure Boot Signer ---
    if [ ! -f "$SIGN_MODULE_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $SIGN_MODULE_SCRIPT not found. Skipping."
    else
        cp "$SIGN_MODULE_SCRIPT" "$SIGN_MODULE_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$SIGN_MODULE_DEST"
            print "    [OK] Secure Boot Module Signer installed to $SIGN_MODULE_DEST"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $SIGN_MODULE_SCRIPT."
        fi
    fi

    # --- [NEW] Install Update Script ---
    if [ ! -f "$UPDATE_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $UPDATE_SCRIPT not found. Skipping."
    else
        cp "$UPDATE_SCRIPT" "$UPDATE_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$UPDATE_DEST"
            print "    [OK] RT Update script installed to $UPDATE_DEST"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $UPDATE_SCRIPT."
        fi
    fi

    # --- Install Google Safe Sites Poller (Defense) ---
    if [ ! -f "$GSB_POLLER_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $GSB_POLLER_SCRIPT not found. Skipping Google Safe Sites."
    else
        cp "$GSB_POLLER_SCRIPT" "$GSB_POLLER_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$GSB_POLLER_DEST"
            print "    [OK] Google Safe Sites Poller (Defense) installed to $GSB_POLLER_DEST"
            
            if test \`cat /proc/1/comm\` = "systemd"; then
                echo "    > Creating systemd service for Google Safe Sites Poller..."
                cat << EOF > "$GSB_SERVICE_FILE"
[Unit]
Description=Revolutionary Technology - Google Safe Sites IP Poller
After=network-online.target csf.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=$GSB_POLLER_DEST
Restart=always
RestartSec=30
User=root

[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                systemctl enable "$GSB_SERVICE_FILE" >/dev/null 2>&1
                systemctl start "$GSB_SERVICE_FILE"
                print "    [OK] Google Safe Sites Poller service created and started."
            else
                print "    [WARN] systemd not found. Google Poller service not created. Script must be run manually."
            fi
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $GSB_POLLER_SCRIPT."
        fi
    fi

    # --- Install Google Block Reporter ---
	# This script runs as a cron job to report malicious domains
	# (discovered via rDNS from blocked IPs) to the Google Web Risk API
	# as a community defense contribution. This tools is ONLY intended for use in notifying
	# network administrators that a malicious attack has come from their network. Some
	# malicious connections come from innocent shared hosts. Shared hosts will be notified
	# with this reporter, that a bad actor exists on their network. This is not designed
	# to block or prevent legitimate traffic.
	#
	# Google's Safe Browsing technology constantly checks reported safe and unsafe websites to verify threats.
	# It uses AI and machine learning to scan billions of URLs daily, identifies malicious scripts and content, 
	# and adds dangerous sites to a list that major browsers use to warn users. If a site is flagged, a website
	# owner can use Google Search Console to request a review after cleaning up the site. 
	# How Google checks websites
	#
	# Daily scanning: Google scans its web index daily, and its Safe Browsing technology checks billions
	# of URLs each day for unsafe websites.
	# Automated analysis: Artificial intelligence (AI) is used to identify patterns of fraudulent content,
	# distinguishing legitimate from harmful sites at scale.
	# Threat detection: The checks are designed to find malicious scripts, downloads, viruses, and 
	# content that violates policies.
	# Real-time checks: Safe Browsing performs real-time checks against lists of known phishing and 
	# malware sites and can even perform deeper scans on downloaded files. 
	#
	# What happens to reported sites
	#
	# Sites are flagged or blocked: When a dangerous site is detected, it can be labeled as dangerous
	# in search results or added to the Safe Browsing list, which browsers use to warn users.
	# Owners can request a review: If a website is flagged, the owner can go to the Security issues section
	# in Google Search Console and request a review after they have cleaned up the site. 
	#
	# Check the status of a website on Google Safe Sites: https://transparencyreport.google.com/safe-browsing/search
	# Why would a page be reported to Google Sage Sites? https://support.google.com/webmasters/answer/6347750?hl=en
	#
    if [ ! -f "$BLOCK_REPORTER_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $BLOCK_REPORTER_SCRIPT not found. Skipping Block Reporter."
    else
        cp "$BLOCK_REPORTER_SCRIPT" "$BLOCK_REPORTER_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$BLOCK_REPORTER_DEST"
            print "    [OK] Block Reporter installed to $BLOCK_REPORTER_DEST"
            
            echo "    > Creating hourly cron job for Block Reporter..."
            # Create a symlink in cron.hourly
            ln -sf "$BLOCK_REPORTER_DEST" "$BLOCK_REPORTER_CRON"
            chmod +x "$BLOCK_REPORTER_CRON"
            print "    [OK] Block Reporter cron job created."
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $BLOCK_REPORTER_SCRIPT."
        fi
    fi
    
    # --- [NEW] Install Google IP Updater ---
    if [ ! -f "$GOOGLE_IP_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $GOOGLE_IP_SCRIPT not found. Skipping Google IP Updater."
    else
        cp "$GOOGLE_IP_SCRIPT" "$GOOGLE_IP_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$GOOGLE_IP_DEST"
            print "    [OK] Google IP Updater (Bot/Voice/Services) installed to $GOOGLE_IP_DEST"
            
            echo "    > Creating daily cron job for Google IP Updater..."
            # This cron runs at a random minute between 3:00 and 5:59 AM server time
            cat << EOF > "$GOOGLE_IP_CRON"
# Revolutionary Technology - Google IP Updater
# Runs daily at a random time between 03:00 and 05:59 server time
$(shuf -i 0-59) $(shuf -i 3-5) * * * root $GOOGLE_IP_DEST > /dev/null 2>&1
EOF
            chmod 644 "$GOOGLE_IP_CRON"
            print "    [OK] Google IP Updater cron job created."
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $GOOGLE_IP_SCRIPT."
        fi
    fi
    
fi # [FIX] This 'fi' was missing, causing the 'else' error.

print ""
# -------------------------------------------------------------------
#  END AUTO-TUNER & TOOLS INTEGRATION
# -------------------------------------------------------------------