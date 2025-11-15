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
#   @updated            11.14.2025
# #
# ... (rest of file) ...
script_dir=$(dirname "$script")

# #
#   Include global
# #
# ... (rest of file) ...
. "$script_dir/global.sh" ||
{
    echo "    Error: cannot source $script_dir/global.sh. Aborting." >&2
    exit 1
}
# ... (rest of file) ...
#   Define directories
#   (Moved definitions here for clarity)
# #
CSF_DIR="/etc/csf"
BIN_DIR="/usr/sbin"
LIB_DIR="/var/lib/csf"
AUTOTUNE_SCRIPT="csf-autotune.sh"
AUTOTUNE_DEST="/usr/local/sbin/csf-autotune.sh"
FIRMWARE_CHECK_SCRIPT="csf-firmware-check.sh"
FIRMWARE_CHECK_DEST="/usr/local/sbin/csf-firmware-check.sh"
GSB_POLLER_SCRIPT="rt-gsb-poller.sh"
GSB_POLLER_DEST="/usr/local/sbin/rt-gsb-poller.sh"
GSB_SERVICE_FILE="/etc/systemd/system/rt-gsb-poller.service"
# [NEW] Block Reporter (Offense)
BLOCK_REPORTER_SCRIPT="rt-block-reporter.sh"
BLOCK_REPORTER_DEST="/usr/local/sbin/rt-block-reporter.sh"
BLOCK_REPORTER_CRON="/etc/cron.hourly/rt-block-reporter"
SANITY_FILE="sanity.txt"


# #
#   Func › Usage Menu
# ... (rest of file) ...
#   Define which installation script to run
# #

if [ -e "/usr/local/cpanel/version" ]; then
# ... (rest of file) ...
else
    run_installer "install.generic.sh" "Generic"
fi

# -------------------------------------------------------------------
#  BEGIN AUTO-TUNER & TOOLS INTEGRATION
# -------------------------------------------------------------------
# ... (rest of file) ...
print ""
print "    Installing CSF Hardware Acceleration Tools..."

# Check that the sub-installer did its job
if [ ! -f "$CSF_DIR/csf.conf" ]; then
# ... (rest of file) ...
    print "    ${redl}[ERROR]${greym} $CSF_DIR/sanity.txt not found. Auto-Tuner cannot run."
else
    # --- Install Auto-Tuner ---
    if [ ! -f "$AUTOTUNE_SCRIPT" ]; then
# ... (rest of file) ...
        print "    ${redl}[ERROR]${greym} $AUTOTUNE_SCRIPT not found in installer directory. Skipping auto-tuning."
    else
        cp "$AUTOTUNE_SCRIPT" "$AUTOTUNE_DEST"
# ... (rest of file) ...
            print "    ${redl}[ERROR]${greym} Failed to copy $AUTOTUNE_SCRIPT to $AUTOTUNE_DEST. Skipping auto-tuning."
        fi
    fi
    
    # --- Install Firmware Checker ---
    if [ ! -f "$FIRMWARE_CHECK_SCRIPT" ]; then
# ... (rest of file) ...
        print "    ${redl}[ERROR]${greym} $FIRMWARE_CHECK_SCRIPT not found. Skipping."
    else
        cp "$FIRMWARE_CHECK_SCRIPT" "$FIRMWARE_CHECK_DEST"
# ... (rest of file) ...
            print "    [OK] Hardware Firmware Checker installed to $FIRMWARE_CHECK_DEST"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $FIRMWARE_CHECK_SCRIPT."
# ... (rest of file) ...
        fi
    fi

    # --- Install Google Safe Sites Poller (Defense) ---
    if [ ! -f "$GSB_POLLER_SCRIPT" ]; then
# ... (rest of file) ...
        print "    ${redl}[ERROR]${greym} $GSB_POLLER_SCRIPT not found. Skipping Google Safe Sites."
    else
        cp "$GSB_POLLER_SCRIPT" "$GSB_POLLER_DEST"
# ... (rest of file) ...
            print "    [OK] Google Safe Sites Poller (Defense) installed to $GSB_POLLER_DEST"
            
            # Create systemd service for the poller
            if test \`cat /proc/1/comm\` = "systemd"; then
# ... (rest of file) ...
                print "    [OK] Google Safe Sites Poller service created and started."
            else
                print "    [WARN] systemd not found. Google Poller service not created. Script must be run manually."
# ... (rest of file) ...
            fi
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $GSB_POLLER_SCRIPT."
# ... (rest of file) ...
        fi
    fi

    # --- [NEW] Install Google Block Reporter (Offense) ---
    if [ ! -f "$BLOCK_REPORTER_SCRIPT" ]; then
        print "    ${redl}[ERROR]${greym} $BLOCK_REPORTER_SCRIPT not found. Skipping Block Reporter."
    else
        cp "$BLOCK_REPORTER_SCRIPT" "$BLOCK_REPORTER_DEST"
         if [ $? -eq 0 ]; then
            chmod +x "$BLOCK_REPORTER_DEST"
            print "    [OK] Block Reporter installed to $BLOCK_REPORTER_DEST"
            
            # Create cron job
            echo "    > Creating hourly cron job for Block Reporter..."
            ln -s "$BLOCK_REPORTER_DEST" "$BLOCK_REPORTER_CRON"
            chmod +x "$BLOCK_REPORTER_CRON"
        else
            print "    ${redl}[ERROR]${greym} Failed to copy $BLOCK_REPORTER_SCRIPT."
        fi
    fi
fi

print ""
# -------------------------------------------------------------------
#  END AUTO-TUNER & TOOLS INTEGRATION
# -------------------------------------------------------------------