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
#   @updated            11.05.2025
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
# #

umask 0177


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

if [ -e "/usr/local/cpanel/version" ]; then
	echo "Running csf cPanel installer"
	echo
	sh install.cpanel.sh
	exit 0
elif [ -e "/usr/local/directadmin/directadmin" ]; then
	echo "Running csf DirectAdmin installer"
	echo
	sh install.directadmin.sh
	exit 0
fi

echo "Installing csf and lfd"
echo

echo "Check we're running as root"
if [ ! `id -u` = 0 ]; then
	echo
	echo "FAILED: You have to be logged in as root (UID:0) to install csf"
	exit
fi
echo

mkdir -v -m 0600 /etc/csf
cp -avf install.txt /etc/csf/

echo "Checking Perl modules..."
chmod 700 os.pl
RETURN=`./os.pl`
if [ "$RETURN" = 1 ]; then
	echo
	echo "FAILED: You MUST install the missing perl modules above before you can install csf. See /etc/csf/install.txt for installation details."
    echo
	exit
else
    echo "...Perl modules OK"
    echo
fi

#
# --- [Revolutionary Tech] Install Build Dependencies (bpfilter, eBPF, Tarpit) & Sign Modules ---
#
print "    Installing Build Dependencies (bpfilter, eBPF, Tarpit)..."
rm -f /tmp/rt_reboot_required /tmp/rt_tarpit_failed

if [ -f /usr/bin/apt-get ]; then
    # --- This is a Debian or Ubuntu system ---
    print "    > Detected apt package manager (Debian/Ubuntu)."
    export DEBIAN_FRONTEND=noninteractive
    # Install dependencies for building bpfilter, eBPF, and tarpit
    apt-get update -y > /dev/null 2>&1
    apt-get install -y git make gcc clang llvm cmake libbpf-dev libxdp-dev \
    libmnl-dev libgmp-dev libnftnl-dev libxtables-dev libnl-3-dev bison flex \
    xtables-addons-common xtables-addons-dkms openssl mokutil \
    linux-headers-$(uname -r) > /dev/null 2>&1
    print "    > Build dependencies installed."

elif [ -f /usr/bin/yum ]; then
    # --- This is a Red Hat, CentOS, or AlmaLinux system ---
    print "    > Detected yum package manager (RHEL/CentOS/AlmaLinux)."
    yum install epel-release -y > /dev/null 2>&1
    # Install dependencies for building bpfilter, eBPF, and tarpit
    yum install -y git make gcc clang llvm cmake libbpf-devel libxdp-devel \
    libmnl-devel gmp-devel libnftnl-devel xtables-devel libnl3-devel bison flex \
    xtables-addons-kmod xtables-addons openssl mokutil \
    kernel-devel-$(uname -r) > /dev/null 2>&1
    print "    > Build dependencies installed."
    
else
    print "    ${redl}WARNING:${greym} Could not find apt or yum. Build dependencies must be installed manually."
fi

# --- [Revolutionary Tech] Secure Boot Module Signing ---
# This block checks if Secure Boot is on. If it is, it runs the signing script.
print "    > Checking Secure Boot state..."
if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state | grep -q "SecureBoot enabled"; then
        print "    > Secure Boot is ENABLED. Running kernel module signer..."
        if [ -f "rt-sign-module.sh" ]; then
            chmod 700 rt-sign-module.sh
            ./rt-sign-module.sh
        else
            print "    ${redl}ERROR:${greym} rt-sign-module.sh not found. Cannot sign modules."
        fi
    else
        print "    > Secure Boot is disabled or not supported. Skipping module signing."
    fi
else
    print "    > mokutil not found. Cannot determine Secure Boot state. Skipping module signing."
fi

# --- [Revolutionary Tech] Final Module Load