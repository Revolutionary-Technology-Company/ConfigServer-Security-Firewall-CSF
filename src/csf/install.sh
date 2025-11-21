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
#   @updated            11.21.2025
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

# --- [NEW] XDP Shield ---
XDP_LOADER_SCRIPT="csf-xdp-loader.sh"
XDP_LOADER_DEST="/usr/local/sbin/csf-xdp-loader.sh"
XDP_SERVICE_FILE="/etc/systemd/system/csf-xdp-loader.service"
XDP_SOURCE_FILE="xdp_echo.c"
XDP_SOURCE_DEST="/usr/local/csf/bpf/xdp_echo.c"

# --- 4. Install UI Assets (Titanium Stunt Mode Enabled) ---
echo -n "Installing UI components..."
# UI Assets
if [ ! -d "/etc/csf/ui" ]; then mkdir -p /etc/csf/ui; fi
cp -af ui/* /etc/csf/ui/

# Generate fresh SSL keys if they don't exist
if [ -f "make_ui_cert.sh" ]; then
    echo ""
    # We removed the silencer (>/dev/null) so you can see the Stunt Mode output!
    sh make_ui_cert.sh
    if [ -f "ui/server.crt" ]; then
        cp -af ui/server.crt /etc/csf/ui/
        cp -af ui/server.key /etc/csf/ui/
        chmod 600 /etc/csf/ui/server.key
    fi
    echo -n "Resuming installation..."
fi
# Messenger Templates
cp -af messenger/* /usr/local/csf/tpl/
echo " done"

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
# #

run_installer()
{
    installer="$1"
    description="$2"

    if [ "$argDetect" = "true" ]; then
		ok "    Detected Installer: ${greenl}$script_dir/$installer${greym} ($description) "
		exit 0
	fi

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

#
# --- [Revolutionary Tech] ModSecurity Log Detection ---
#
print ""
print "    Detecting ModSecurity configuration..."

MODSEC_LOG_PATH=""

if [ -f "/etc/apache2/logs/modsec_audit.log" ] || \
   [ -f "/var/log/modsec_audit.json" ] || \
   [ -f "/var/log/httpd/modsec_audit.log" ] || \
   [ -f "/var/log/apache2/modsec_audit.log" ]; then
    print "    ModSecurity 3 detected."
    MODSEC_LOG_PATH="/var/log/modsec_compat.log"
else
    print "    ModSecurity 3 not found. Checking for ModSec2..."
    if [ -f "/usr/local/apache/logs/modsec_audit.log" ]; then
        MODSEC_LOG_PATH="/usr/local/apache/logs/modsec_audit.log"
    elif [ -f "/var/log/modsec_audit.log" ]; then
        MODSEC_LOG_PATH="/var/log/modsec_audit.log"
    else
        print "    No standard ModSecurity log found. Leaving default."
        MODSEC_LOG_PATH="/var/log/modsec_audit.log"
    fi
fi

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
    
    # ==============================================================================
    # [Revolutionary Tech] XDP/eBPF & Kernel Toolchain Installation
    # ==============================================================================
    print "    Checking and installing Kernel Headers & BPF Toolchain..."

    # 1. Check Kernel Version (Must be >= 4.18 for reliable XDP)
    KERNEL_MAJOR=$(uname -r | cut -d. -f1)
    KERNEL_MINOR=$(uname -r | cut -d. -f2)

    if [ "$KERNEL_MAJOR" -lt 4 ] || ( [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 18 ] ); then
        print "    ${yellowl}[WARN] Kernel $(uname -r) is too old for XDP/BPF. Skipping tools.${greym}"
    else
        print "    > Kernel $(uname -r) supports XDP/BPF. Proceeding..."

        # 2. Detect OS and Install Packages
        if [ -f /etc/redhat-release ]; then
            # RHEL / CentOS / AlmaLinux / Rocky
            print "    > Detected RHEL-family. Installing via yum/dnf..."
            if ! rpm -q epel-release >/dev/null 2>&1; then
                 yum install -y epel-release >/dev/null 2>&1
            fi
            yum install -y kernel-devel-$(uname -r) bpftool xdp-tools bpfilter bpfilter-devel >/dev/null 2>&1 || print "    > (Note: Some packages may be missing from repos, continuing...)"

        elif [ -f /etc/debian_version ]; then
            # Debian / Ubuntu
            print "    > Detected Debian-family. Installing via apt..."
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y >/dev/null 2>&1
            apt-get install -y linux-headers-$(uname -r) linux-tools-$(uname -r) linux-tools-common xdp-tools bpftool bpfilter bpfilter-devel >/dev/null 2>&1 || print "    > (Note: Some packages may be missing from repos, continuing...)"
            
        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            print "    > Detected Arch Linux. Installing via pacman..."
            pacman -Sy --noconfirm linux-headers bpftool xdp-tools bpfilter >/dev/null 2>&1
            
        elif [ -f /etc/SuSE-release ] || [ -f /etc/os-release ] && grep -q "ID.*suse" /etc/os-release; then
            # OpenSUSE / SLES
            print "    > Detected SUSE. Installing via zypper..."
            zypper --non-interactive refresh >/dev/null 2>&1
            zypper --non-interactive install kernel-devel bpftool xdp-tools bpfilter bpfilter-devel >/dev/null 2>&1
        else
            print "    ${yellowl}[WARN] Unsupported OS for automatic install. Please install 'kernel-devel' manually.${greym}"
        fi

        # 3. Verify XDP/BPF Readiness
        if [ -d "/usr/src/kernels/$(uname -r)" ] || [ -d "/usr/src/linux-headers-$(uname -r)" ]; then
            print "    ${greenl}[OK] Kernel headers found for $(uname -r). BPF compilation ready.${greym}"
        else
            print "    ${yellowl}[WARN] Kernel headers could not be verified. Custom BPF compilation may fail.${greym}"
        fi

        # 4. Install XDP Shield Loader & Files
        if command -v xdp-filter >/dev/null 2>&1; then
            
            # --- Install XDP Loader Script ---
            if [ -f "$XDP_LOADER_SCRIPT" ]; then
                print "    > Installing XDP Loader and Filter Logic..."
                cp -avf "$XDP_LOADER_SCRIPT" "$XDP_LOADER_DEST"
                chmod 700 "$XDP_LOADER_DEST"
            else
                print "    ${redl}[ERROR] $XDP_LOADER_SCRIPT not found in source directory.${greym}"
            fi

            # --- Install XDP Source Code (For ECHO/DROP) ---
            if [ -f "$XDP_SOURCE_FILE" ]; then
                # Ensure /usr/local/csf/bpf/ exists (created by sub-installers, but good to verify)
                mkdir -p -m 0600 /usr/local/csf/bpf/
                cp -avf "$XDP_SOURCE_FILE" "$XDP_SOURCE_DEST"
            fi
            
            print "    > Creating persistent XDP loader service..."
            cat <<EOF > "$XDP_SERVICE_FILE"
[Unit]
Description=Revolutionary Technology XDP DDoS Filter Loader
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$XDP_LOADER_DEST start
ExecStop=$XDP_LOADER_DEST stop

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable "$(basename $XDP_SERVICE_FILE)" >/dev/null 2>&1
            print "    [OK] XDP Loader Service enabled."
        else
            print "    ${redl}[ERROR] xdp-filter binary not found. Skipping XDP service creation.${greym}"
        fi
    fi
    # ==============================================================================
    
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

    # --- Install Stress Engine ---
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

    # --- Install Secure Boot Signer ---
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

    # --- Install Update Script ---
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
            
            if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
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
                systemctl enable "$(basename $GSB_SERVICE_FILE)" >/dev/null 2>&1
                systemctl start "$(basename $GSB_SERVICE_FILE)"
                print "    [OK] Google Safe Sites Poller service created and started."
            else
                print "    [WARN] systemd not found. Google Poller service not created. Script must be run manually."
            fi
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $GSB_POLLER_SCRIPT."
        fi
    fi

    # --- Install Google Block Reporter ---
    if [ ! -f "$BLOCK_REPORTER_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $BLOCK_REPORTER_SCRIPT not found. Skipping Block Reporter."
    else
        cp "$BLOCK_REPORTER_SCRIPT" "$BLOCK_REPORTER_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$BLOCK_REPORTER_DEST"
            print "    [OK] Block Reporter installed to $BLOCK_REPORTER_DEST"
            
            echo "    > Creating hourly cron job for Block Reporter..."
            ln -sf "$BLOCK_REPORTER_DEST" "$BLOCK_REPORTER_CRON"
            chmod +x "$BLOCK_REPORTER_CRON"
            print "    [OK] Block Reporter cron job created."
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $BLOCK_REPORTER_SCRIPT."
        fi
    fi
    
    # --- Install Google IP Updater ---
    if [ ! -f "$GOOGLE_IP_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $GOOGLE_IP_SCRIPT not found. Skipping Google IP Updater."
    else
        cp "$GOOGLE_IP_SCRIPT" "$GOOGLE_IP_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$GOOGLE_IP_DEST"
            print "    [OK] Google IP Updater (Bot/Voice/Services) installed to $GOOGLE_IP_DEST"
            
            echo "    > Creating daily cron job for Google IP Updater..."
            cat << EOF > "$GOOGLE_IP_CRON"
# Revolutionary Technology - Google IP Updater
# Runs daily at a random time between 03:00 and 05:59 server time
$(shuf -i 0-59 -n 1) $(shuf -i 3-5 -n 1) * * * root $GOOGLE_IP_DEST > /dev/null 2>&1
EOF
            chmod 644 "$GOOGLE_IP_CRON"
            print "    [OK] Google IP Updater cron job created."
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $GOOGLE_IP_SCRIPT."
        fi
    fi

fi 

print ""
# -------------------------------------------------------------------
#  END AUTO-TUNER & TOOLS INTEGRATION
# -------------------------------------------------------------------