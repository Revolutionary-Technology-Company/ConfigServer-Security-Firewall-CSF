#!/bin/bash
#
# CSF Auto-Tuner (csf-autotune.sh)
#
# This script dynamically tunes /etc/csf/csf.conf settings AND
# kernel-level netfilter/offloading settings based on available system resources.
# It respects the validation rules in /etc/csf/sanity.txt.
#
# Developed for Revolutionary Technology & Aetherinox
#

CONF_FILE="/etc/csf/csf.conf"
SANITY_FILE="/etc/csf/sanity.txt"
BACKUP_FILE="/etc/csf/csf.conf.autotune.bak"
KERNEL_TUNE_FILE="/etc/sysctl.d/99-csf-tuning.conf"
RPS_SERVICE_FILE="/etc/systemd/system/csf-rps-tuner.service"

# --- Helper Functions ---

# Function to safely update csf.conf
# $1 = Key (e.g., CT_LIMIT)
# $2 = Value (e.g., "300")
update_config() {
    local key=$1
    local value=$2
    if ! grep -q "^\s*$key\s*=" "$CONF_FILE"; then
        echo "  [SKIP] $key not found in $CONF_FILE. Skipping."
        return
    fi
    
    # Use sed to replace the value, handling whitespace and quotes
    sed -i -E "s|^(\s*$key\s*=\s*)\".*\"|\1\"$value\"|" "$CONF_FILE"
    echo "  [SET] $key = \"$value\""
}

# Function to check a value against sanity.txt
# $1 = Key (e.g., PT_USERPROC)
# $2 = Value (e.g., 150)
check_sanity() {
    local key=$1
    local value=$2
    local sanity_line=$(grep "^${key}=" "$SANITY_FILE")

    if [ -z "$sanity_line" ]; then
        echo "  [WARN] No sanity.txt entry for $key. Skipping check."
        return 0 # 0 = true/success
    fi

    local ranges=$(echo "$sanity_line" | cut -d'=' -f2)
    
    if [[ "$ranges" == *\|* ]]; then
        # Option list (e.g., DROP=DROP|TARPIT|DROP)
        # Handle simple options
        local options_part=$(echo "$ranges" | cut -d'=' -f1)
        local options=$(echo "$options_part" | tr '|' ' ')
        
        for opt in $options; do
            if [ "$opt" == "$value" ]; then
                return 0 # Value is valid
            fi
        done
        
        # Handle complex options like CT_LIMIT=0|10-1000=0
        if [[ "$ranges" == *-* ]]; then
            # This is a range with a '|' prefix, fall through to range check
            :
        else
            echo "  [FAIL] $key=$value is not in valid options ($options)."
            return 1 # 1 = false/fail
        fi

    fi
    
    if [[ "$ranges" == *-* ]]; then
        # Number range (e.g., PT_USERPROC=0-14000=55 or CT_LIMIT=0|10-1000=0)
        local range_part=$(echo "$ranges" | cut -d'=' -f1)
        
        # Handle special case like CT_LIMIT=0|10-1000=0
        if [[ "$range_part" == *\|* ]]; then
            local special_val=$(echo "$range_part" | cut -d'|' -f1)
            if [ "$value" == "$special_val" ]; then
                return 0 # 0 is a valid value
            fi
            # Adjust range_part to be the simple range
            range_part=$(echo "$range_part" | cut -d'|' -f2) # now range_part is 10-1000
        fi

        local min=$(echo "$range_part" | cut -d'-' -f1)
        local max=$(echo "$range_part" | cut -d'-' -f2)

        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo "  [FAIL] $key=$value is not a number."
            return 1
        fi
        
        if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
            echo "  [FAIL] $key=$value is outside sane range ($min-$max)."
            return 1
        fi
        return 0 # It's in range
    fi
    
    echo "  [WARN] Unknown sanity.txt format for $key. Skipping check."
    return 0
}

# --- [NEW] Hardware Offloading Function ---
# Enables Receive Packet Steering (RPS) to spread network load across all CPUs
enable_rps() {
    local cpu_cores=$1
    if [ -z "$cpu_cores" ]; then
        echo "  [FAIL] CPU cores not provided to enable_rps."
        return
    fi
    
    # Detect primary NIC
    local nic=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [ -z "$nic" ]; then
        echo "  [WARN] Could not detect primary NIC. Skipping RPS (Hardware Offload) tuning."
        return
    fi
    
    echo ""
    echo "Applying Network Hardware Offloads (RPS) for $nic..."
    
    # Calculate CPU mask (e.g., 8 cores = 11111111 binary = ff hex)
    local cpu_mask=$(printf '%x' $((2**cpu_cores - 1)))
    
    if [ -z "$cpu_mask" ]; then
        echo "  [FAIL] Could not calculate CPU mask. Skipping RPS."
        return
    fi
    
    local rps_queues_applied=0
    for queue in /sys/class/net/$nic/queues/rx-*; do
        if [ -f "$queue/rps_cpus" ]; then
            echo "$cpu_mask" > "$queue/rps_cpus"
            echo "  [SET] RPS CPU mask $cpu_mask for $queue"
            rps_queues_applied=$((rps_queues_applied + 1))
        fi
    done
    
    if [ "$rps_queues_applied" -gt 0 ]; then
        echo "  [OK] RPS enabled on $rps_queues_applied receive queues."
        # Create systemd service to make it persistent
        echo "Creating persistent service file: $RPS_SERVICE_FILE"
        cat << EOF > "$RPS_SERVICE_FILE"
[Unit]
Description=CSF Persistent RPS Tuner (Hardware Offload)
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "
    CPU_CORES=\$(nproc);
    CPU_MASK=\$(printf '%x' \$((2**CPU_CORES - 1)));
    NIC=\$(ip route get 1.1.1.1 2>/dev/null | awk '{print \$5; exit}');
    if [ -n \"\$NIC\" ]; then
        for queue in /sys/class/net/\$NIC/queues/rx-*; do
            [ -f \"\$queue/rps_cpus\" ] && echo \"\$CPU_MASK\" > \"\$queue/rps_cpus\";
        done;
    fi
"

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "$RPS_SERVICE_FILE" >/dev/null 2>&1
        echo "  [OK] RPS settings made persistent."
    else
        echo "  [WARN] No RPS-compatible queues found for $nic. Skipping."
    fi
}

# --- Main Execution ---

echo "Starting CSF Auto-Tuner..."

# 1. Check for required files
if [ ! -f "$CONF_FILE" ]; then
    echo "ERROR: $CONF_FILE not found."
    exit 1
fi
if [ ! -f "$SANITY_FILE" ]; then
    echo "ERROR: $SANITY_FILE not found. Cannot perform sanity checks."
    exit 1
fi

# 2. Hardware Detection
CPU_CORES=$(nproc)
RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')

# Check for SSD (ROTA=0) vs HDD (ROTA=1)
DISK_TYPE="HDD" # Default to HDD
for dev in $(lsblk -dno NAME,TYPE | grep 'disk' | awk '{print $1}'); do
    # /sys/block/DEVICE/queue/rotational is the most reliable check
    if [ -f "/sys/block/$dev/queue/rotational" ] && [ "$(cat /sys/block/$dev/queue/rotational 2>/dev/null)" == "0" ]; then
        DISK_TYPE="SSD"
        break # Found an SSD, we can stop
    fi
done

echo "--------------------------------"
echo "System Hardware Detected:"
echo "  CPU Cores: $CPU_CORES"
echo "  Total RAM: $RAM_MB MB"
echo "  Disk Type: $DISK_TYPE"
echo "--------------------------------"

# 3. Profile Selection
PROFILE="Balanced" # Default
if [ "$CPU_CORES" -lt 2 ] || [ "$RAM_MB" -lt 2048 ]; then
    PROFILE="Low Resource"
elif [ "$CPU_CORES" -gt 8 ] && [ "$RAM_MB" -gt 16384 ]; then
    PROFILE="Max Performance" # Changed from High Performance
fi

echo "Selected Profile: $PROFILE"
echo ""

# 4. Define Tuned Settings
declare -A TUNE_SETTINGS
declare -A KERNEL_SETTINGS

case "$PROFILE" in
    "Low Resource")
        echo "Applying 'Low Resource' settings (e.g., VPS, < 2GB RAM)"
        TUNE_SETTINGS["CT_LIMIT"]="100"
        TUNE_SETTINGS["CT_INTERVAL"]="60"   # Slower check
        TUNE_SETTINGS["CONNLIMIT"]="80;20"
        TUNE_SETTINGS["PT_INTERVAL"]="300"  # Slower check
        TUNE_SETTINGS["PT_USERPROC"]="40"
        TUNE_SETTINGS["PT_USERMEM"]="256" # From sanity.txt
        TUNE_SETTINGS["PT_USERTIME"]="18000"
        TUNE_SETTINGS["LF_IPSET"]="0"
        TUNE_SETTINGS["LF_IPSET_HASHSIZE"]="16384"
        TUNE_SETTINGS["LF_IPSET_MAXELEM"]="32768"
        TUNE_SETTINGS["DENY_IP_LIMIT"]="200"
        TUNE_SETTINGS["DENY_TEMP_IP_LIMIT"]="100"
        TUNE_SETTINGS["FASTSTART"]="0"
        TUNE_SETTINGS["DROP_IP_LOGGING"]="0"
        
        # Kernel settings
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_max"]="65536"
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_buckets"]="16384"
        ;;
    "Balanced")
        echo "Applying 'Balanced' settings (e.g., Standard Server, 2-16GB RAM)"
        TUNE_SETTINGS["CT_LIMIT"]="300"
        TUNE_SETTINGS["CT_INTERVAL"]="30"   # Default check
        TUNE_SETTINGS["CONNLIMIT"]="150;30,443;20"
        TUNE_SETTINGS["PT_INTERVAL"]="180"  # Default check
        TUNE_SETTINGS["PT_USERPROC"]="55"      # Default from sanity.txt
        TUNE_SETTINGS["PT_USERMEM"]="512"
        TUNE_SETTINGS["PT_USERTIME"]="27500"   # Default from sanity.txt
        TUNE_SETTINGS["LF_IPSET"]="1" # Enable ipset
        TUNE_SETTINGS["LF_IPSET_HASHSIZE"]="65536"
        TUNE_SETTINGS["LF_IPSET_MAXELEM"]="131072"
        TUNE_SETTINGS["DENY_IP_LIMIT"]="400"
        TUNE_SETTINGS["DENY_TEMP_IP_LIMIT"]="200"
        TUNE_SETTINGS["FASTSTART"]="1" # Enable faststart
        TUNE_SETTINGS["DROP_IP_LOGGING"]="0"

        # Kernel settings
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_max"]="262144" # 256k conns
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_buckets"]="65536"
        ;;
    "Max Performance")
        echo "Applying 'Max Performance' settings (Using 12% resource slice)"
        TUNE_SETTINGS["CT_LIMIT"]="1000"            # Max Sane Connections
        TUNE_SETTINGS["CT_INTERVAL"]="15"           # Aggressive check (15s)
        TUNE_SETTINGS["CONNLIMIT"]="400;50,443;40"  # High connlimit
        TUNE_SETTINGS["PT_INTERVAL"]="60"           # Aggressive check (60s)
        TUNE_SETTINGS["PT_USERPROC"]="150"          # Sane limit based on logs
        TUNE_SETTINGS["PT_USERMEM"]="1024"          # Max Sane Memory
        TUNE_SETTINGS["PT_USERTIME"]="100000"       # Max Sane Time
        TUNE_SETTINGS["LF_IPSET"]="1"               # CRITICAL: Enable ipset
        TUNE_SETTINGS["LF_IPSET_HASHSIZE"]="393216" # Max RAM for IP sets
        TUNE_SETTINGS["LF_IPSET_MAXELEM"]="196608" # Max RAM for IP sets
        TUNE_SETTINGS["DENY_IP_LIMIT"]="1000"       # Max Sane Perm Deny
        TUNE_SETTINGS["DENY_TEMP_IP_LIMIT"]="1000"  # Max Sane Temp Deny
        TUNE_SETTINGS["FASTSTART"]="1"              # CRITICAL: Enable faststart
        TUNE_SETTINGS["DROP_IP_LOGGING"]="0"        # Reduce log I/O
        
        # Kernel settings: Use 12% RAM slice
        # Rule: 64 connections per MB of RAM. (e.g., 16GB = 16384 * 64 = ~1M)
        CONNTRACK_MAX=$((RAM_MB * 64))
        # Buckets = MAX / 4
        CONNTRACK_BUCKETS=$((CONNTRACK_MAX / 4))
        
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_max"]="$CONNTRACK_MAX"
        KERNEL_SETTINGS["net.netfilter.nf_conntrack_buckets"]="$CONNTRACK_BUCKETS"
        
        # [NEW] Call the RPS/Offloading function
        enable_rps "$CPU_CORES"
        ;;
esac

# 5. SSD Optimizations
echo ""
echo "Applying Disk Optimizations..."
if [ "$DISK_TYPE" == "SSD" ]; then
    echo "  [INFO] SSD detected. Enabling disk stats."
    TUNE_SETTINGS["ST_DISKW"]="1"
    TUNE_SETTINGS["ST_DISKW_FREQ"]="15" # Check every 15 mins
else
    echo "  [INFO] HDD detected. Disabling 'dd' disk write test to reduce I/O."
    TUNE_SETTINGS["ST_DISKW"]="0"
    TUNE_SETTINGS["ST_DISKW_FRIO"]="60" # Check less often if re-enabled
fi


# 6. Apply Kernel-level Optimizations FIRST
echo ""
echo "Applying Kernel (sysctl) optimizations..."
{
    echo "# -------------------------------------------------------------------"
    echo "# Auto-generated by CSF Auto-Tuner for Revolutionary Technology"
    echo "# Profile: $PROFILE"
    echo "# This file dedicates system RAM (your 12% slice) to connection"
    echo "# tracking to speed up the firewall and prevent connection drops."
    echo "# -------------------------------------------------------------------"
    echo ""
    for key in "${!KERNEL_SETTINGS[@]}"; do
        value="${KERNEL_SETTINGS[$key]}"
        echo "  [SET] $key = $value"
        echo "$key = $value"
    done
    echo ""
    echo "# End of auto-generated settings"
} > "$KERNEL_TUNE_FILE"

# Apply the new kernel settings immediately
echo "Loading new kernel settings from $KERNEL_TUNE_FILE..."
if sysctl -p "$KERNEL_TUNE_FILE" 2>/dev/null; then
    echo "  [OK] Kernel settings applied."
else
    echo "  [WARN] Could not apply kernel settings via sysctl. They will be loaded on next boot."
fi

# 7. Backup and Apply CSF Settings
echo ""
echo "Backing up $CONF_FILE to $BACKUP_FILE..."
cp "$CONF_FILE" "$BACKUP_FILE"

echo ""
echo "Applying and validating csf.conf settings..."
for key in "${!TUNE_SETTINGS[@]}"; do
    value="${TUNE_SETTINGS[$key]}"
    
    # Check against sanity.txt BEFORE applying
    if check_sanity "$key" "$value"; then
        update_config "$key" "$value"
    else
        echo "  [ABORT] $key=$value failed sanity check. Setting will NOT be applied."
    fi
done

echo ""
echo "--------------------------------"
echo "Auto-Tuning Complete."
echo "Review changes and restart csf with: csf -ra"
echo "--------------------------------"