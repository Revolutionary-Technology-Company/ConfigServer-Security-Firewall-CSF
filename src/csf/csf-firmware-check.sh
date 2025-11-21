#!/bin/bash
#
# CSF Hardware Firmware Checker
#
# This utility provides a report on the active NIC drivers and firmware
# to verify if the system is "Hardware Acceleration-Ready" for the
# 10x speed boost.
#
# Run this to diagnose performance or send the report to support.
#
# Developed for Revolutionary Technology & Aetherinox
#

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}-----------------------------------------------------${NC}"
echo -e "  Revolutionary Technology - Hardware Acceleration Report"
echo -e "${BLUE}-----------------------------------------------------${NC}"

# --- 1. Check for ethtool ---
if ! command -v ethtool &> /dev/null; then
    echo -e "${RED}[FATAL] \`ethtool\` is not installed.${NC}"
    echo "Please install \`ethtool\` (e.g., \`yum install ethtool\`) to check firmware."
    exit 1
fi

# --- 2. Check for lspci ---
if ! command -v lspci &> /dev/null; then
    echo -e "${RED}[FATAL] \`lspci\` is not installed.${NC}"
    echo "Please install \`pciutils\` (e.g., \`yum install pciutils\`) to check drivers."
    exit 1
fi

# --- 3. Detect Primary NIC ---
NIC=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
if [ -z "$NIC" ]; then
    echo -e "${RED}[ERROR] Could not detect primary network interface.${NC}"
    exit 1
fi

echo -e "Detected Primary NIC: ${GREEN}$NIC${NC}"
echo ""

# --- 4. Get Driver and Firmware Info ---
echo -e "${BLUE}--- Driver & Firmware Details (ethtool) ---${NC}"
DRIVER_INFO=$(ethtool -i "$NIC" 2>/dev/null)
if [ -z "$DRIVER_INFO" ]; then
    echo -e "${YELLOW}[WARN] Could not get driver details from ethtool for $NIC.${NC}"
else
    echo "$DRIVER_INFO"
fi
echo ""

# --- 5. Get PCI Bus Info ---
echo -e "${BLUE}--- PCI Bus & Kernel Driver (lspci) ---${NC}"
PCI_INFO=$(lspci -v -s $(ethtool -i $NIC 2>/dev/null | grep bus-info | awk '{print $2}') 2>/dev/null)
if [ -z "$PCI_INFO" ]; then
    echo -e "${YELLOW}[WARN] Could not get PCI bus details for $NIC.${NC}"
else
    # Show only the relevant block
    echo "$PCI_INFO" | grep -A 2 -B 2 "Kernel driver in use"
fi
echo ""

# --- 6. Check Virtualization Driver ---
if lspci | grep -qi "VMware"; then
    echo -e "${BLUE}--- Virtualization Check ---${NC}"
    echo "VMware environment detected."
    if lsmod | grep -q "^vmxnet3"; then
        echo -e "[${GREEN}OK${NC}]    High-speed 'vmxnet3' driver is ACTIVE."
    else
        echo -e "[${RED}FAIL${NC}]  High-speed 'vmxnet3' driver is NOT active."
        echo "        Hardware acceleration (10x speed) will fail."
        echo "        ACTION: Install 'open-vm-tools' and change NIC type to 'VMXNET 3'."
    fi
    echo ""
fi


# --- 7. Final Verdict ---
echo -e "${BLUE}--- Acceleration-Ready Verdict ---${NC}"
if echo "$DRIVER_INFO" | grep -q "vmxnet3" || echo "$PCI_INFO" | grep -q "Kernel driver in use: vmxnet3"; then
    echo -e "[${GREEN}READY${NC}] System is Acceleration-Ready (VMware)."
elif [ -n "$DRIVER_INFO" ] && [ -n "$PCI_INFO" ]; then
     echo -e "[${GREEN}READY${NC}] System appears to be Acceleration-Ready (Bare Metal)."
else
     echo -e "[${YELLOW}WARN${NC}]  Could not fully determine hardware status. Please review output."
fi
echo "Ensure 'csf-autotune.sh' has been run to enable hardware offloads."
echo -e "${BLUE}-----------------------------------------------------${NC}"