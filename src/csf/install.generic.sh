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
#   @updated            11.19.2025
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

echo "Installing generic csf and lfd"
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

# --- [Revolutionary Tech] Final Module Load Test ---
print "    > Loading xt_TARPIT module..."
if ! modprobe xt_TARPIT; then
    print "    ${redl}WARNING:${greym} Failed to load xt_TARPIT module. Tarpit functionality may not work."
    echo "1" > /tmp/rt_tarpit_failed
else
    print "    ${greenl}[+] Tarpit module loaded successfully.${greym}"
fi
# --- [Revolutionary Tech] End Build Dependencies Block ---
#

#
# --- [Revolutionary Tech] Build bpfilter & Patched iptables ---
#
print "    Building bpfilter and 'iptables-bpf' integration..."
BUILD_DIR="/usr/src/rt-build"
BPF_IPTABLES_BIN="/usr/local/sbin/iptables-bpf"
BPF_DAEMON_BIN="/usr/local/sbin/bpfilterd"
BPFILTER_REPO="https://github.com/facebook/bpfilter.git"

# --- 1. Clean and create build directory ---
print "    > Preparing build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR" ]; then
    error "    ❌ FAILED: Could not create build directory $BUILD_DIR. Aborting bpfilter build."
else
    # --- 2. Clone the repository ---
    print "    > Cloning $BPFILTER_REPO..."
    git clone --depth 1 "$BPFILTER_REPO" "$BUILD_DIR" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        error "    ❌ FAILED: Could not clone bpfilter repository. Aborting bpfilter build."
    else
        print "    > Repository cloned successfully."
        
        # --- 3. Build the patched iptables ---
        print "    > Building 'iptables-bpf' (This may take a few minutes)..."
        cd "$BUILD_DIR"
        
        # Configure using CMake (disables docs/tests for a faster build)
        cmake -S . -B build -DNO_DOCS=ON -DNO_TESTS=ON -DNO_CHECKS=ON -DNO_BENCHMARKS=ON > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            error "    ❌ FAILED: cmake configuration failed. Aborting bpfilter build."
        else
            # Build the custom iptables target
            make -C build iptables > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                error "    ❌ FAILED: 'make iptables' command failed. Aborting bpfilter build."
            else
                # --- 4. Install the new binary ---
                print "    > Build successful. Installing binaries..."
                if [ -f "build/output/sbin/iptables-bpf" ]; then
                    cp "build/output/sbin/iptables-bpf" "$BPF_IPTABLES_BIN"
                    chmod +x "$BPF_IPTABLES_BIN"
                    ok "    > Installed: $BPF_IPTABLES_BIN"
                else
                    error "    ❌ FAILED: Cannot find built binary 'build/output/sbin/iptables-bpf'."
                fi
                
                # --- 5. Install the bpfilter daemon ---
                if [ -f "build/output/sbin/bpfilter" ]; then
                    cp "build/output/sbin/bpfilter" "$BPF_DAEMON_BIN"
                    chmod +x "$BPF_DAEMON_BIN"
                    ok "    > Installed: $BPF_DAEMON_BIN"
                else
                    error "    ❌ FAILED: Cannot find built binary 'build/output/sbin/bpfilter'."
                fi
            fi
        fi
        
        # Return to original script directory
        cd "$script_dir"
    fi
fi
# --- [Revolutionary Tech] End bpfilter Build Block ---
#

mkdir -v -m 0600 /etc/csf
mkdir -v -m 0600 /var/lib/csf
mkdir -v -m 0600 /var/lib/csf/backup
mkdir -v -m 0600 /var/lib/csf/Geo
mkdir -v -m 0600 /var/lib/csf/ui
mkdir -v -m 0600 /var/lib/csf/stats
mkdir -v -m 0600 /var/lib/csf/lock
mkdir -v -m 0600 /var/lib/csf/webmin
mkdir -v -m 0600 /var/lib/csf/zone
mkdir -v -m 0600 /usr/local/csf
mkdir -v -m 0600 /usr/local/csf/bin
mkdir -v -m 0600 /usr/local/csf/lib
mkdir -v -m 0600 /usr/local/csf/tpl

#
# --- [Revolutionary Tech] Install BPF/XDP Loader & Rules ---
#
print "    Installing BPF/XDP loader script and rules directory..."
mkdir -v -m 0755 /etc/csf/bpf.d
if [ -f "csf-bpf-loader.sh" ]; then
    cp -avf csf-bpf-loader.sh /usr/local/csf/bin/csf-bpf-loader.sh
    chmod 700 /usr/local/csf/bin/csf-bpf-loader.sh
    ok "    > BPF loader script installed."
else
    warn "    > csf-bpf-loader.sh not found in source. Skipping."
fi
if [ -d "bpf.d" ]; then
    cp -avf bpf.d/* /etc/csf/bpf.d/
    ok "    > BPF rules directory populated."
else
    warn "    > 'bpf.d' directory not found in source. Skipping rules copy."
fi

# --- Compile the Drop/Echo Rule ---
print "    > Compiling BPF Drop/Echo rule..."

cat << 'EOF' > /etc/csf/bpf.d/csf_xdp_drop.c
// 
// CSF XDP Drop Actions & Zero Trust Whitelisting
//
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/udp.h>
#include <linux/tcp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);
    __type(value, __u32);
} csf_drop_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_udp_allow_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_tcp_allow_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u32);
} csf_conf_map SEC(".maps");

static inline void swap_src_dst(void *data, struct ethhdr *eth, struct iphdr *ip) {
    unsigned char tmp_mac[ETH_ALEN];
    __builtin_memcpy(tmp_mac, eth->h_source, ETH_ALEN);
    __builtin_memcpy(eth->h_source, eth->h_dest, ETH_ALEN);
    __builtin_memcpy(eth->h_dest, tmp_mac, ETH_ALEN);
    __u32 tmp_ip = ip->saddr;
    ip->saddr = ip->daddr;
    ip->daddr = tmp_ip;
}

SEC("xdp")
int csf_firewall_prog(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data;
    struct iphdr *ip;

    if ((void *)(eth + 1) > data_end) return XDP_PASS;
    if (eth->h_proto != bpf_htons(ETH_P_IP)) return XDP_PASS;
    ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end) return XDP_PASS;

    // 1. Check Dynamic Blocklist
    __u32 src_ip = ip->saddr;
    __u32 *action = bpf_map_lookup_elem(&csf_drop_map, &src_ip);
    if (action) {
        if (*action == 1) { // ECHO
            swap_src_dst(data, eth, ip);
            return XDP_TX;
        }
        return XDP_DROP;
    }

    // 2. Strict UDP Whitelist
    if (ip->protocol == IPPROTO_UDP) {
        __u32 key_udp_strict = 0;
        __u32 *udp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_udp_strict);
        if (udp_strict_flag && *udp_strict_flag == 1) {
            struct udphdr *udp = (void*)ip + sizeof(*ip);
            if ((void*)udp + sizeof(*udp) > data_end) return XDP_PASS;
            __u32 dest_port = bpf_ntohs(udp->dest);
            __u32 *allowed = bpf_map_lookup_elem(&csf_udp_allow_map, &dest_port);
            if (!allowed) return XDP_DROP;
        }
    }

    // 3. Strict TCP Whitelist
    if (ip->protocol == IPPROTO_TCP) {
        __u32 key_tcp_strict = 1;
        __u32 *tcp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_tcp_strict);
        if (tcp_strict_flag && *tcp_strict_flag == 1) {
            struct tcphdr *tcp = (void*)ip + sizeof(*ip);
            if ((void*)tcp + sizeof(*tcp) > data_end) return XDP_PASS;
            __u32 dest_port = bpf_ntohs(tcp->dest);
            __u32 *allowed = bpf_map_lookup_elem(&csf_tcp_allow_map, &dest_port);
            if (!allowed) return XDP_DROP;
        }
    }

    return XDP_PASS;
}
char _license[] SEC("license") = "GPL";
EOF

if command -v clang >/dev/null 2>&1; then
    print "    > Compiling csf_xdp_drop.c..."
    clang -O2 -g -target bpf -c /etc/csf/bpf.d/csf_xdp_drop.c -o /etc/csf/bpf.d/csf_xdp_drop.o >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        ok "    > BPF Drop/Echo rule compiled successfully: /etc/csf/bpf.d/csf_xdp_drop.o"
        chmod 644 /etc/csf/bpf.d/csf_xdp_drop.o
    else
        error "    > Failed to compile BPF Drop/Echo rule."
    fi
else
    warn "    > clang not found. Cannot compile BPF rules."
fi
# --- [Revolutionary Tech] End BPF/XDP Block ---
#

# ==============================================================================
# [Revolutionary Tech] RT CONTROL - IMMEDIATE TRIAGE (DUAL STACK)
# ==============================================================================
print "    [RT-Control] Engaging Immediate DDoS Protection..."

# 1. Kernel Hardening (Universal)
sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null 2>&1
echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
sysctl -p > /dev/null 2>&1

# 2. LAYER A: Native NFTables (If available)
# We apply this first. If the OS supports 'nft', we lock it down natively.
if command -v nft >/dev/null 2>&1; then
    print "    > [Layer A] NFTables binary found. Applying NATIVE filters..."

    # A. Create Table & Chain
    # Priority -1000 places this BEFORE connection tracking (Raw equivalent)
    nft add table inet rt_emergency 2>/dev/null
    nft add chain inet rt_emergency input { type filter hook input priority -1000\; policy accept\; } 2>/dev/null

    # B. Create Dynamic Blacklist Set (The "Penalty Box")
    # Types: IPv4 address. Flags: Dynamic (auto-update), Timeout (auto-expire).
    nft add set inet rt_emergency flooders { type ipv4_addr\; flags dynamic, timeout\; timeout 10m\; } 2>/dev/null

    # C. Drop Malformed Headers (The "IHL" Check)
    # NFT Native: Check if IP Header Length is NOT 5 (standard).
    nft add rule inet rt_emergency input ip version 4 ip ihl != 5 drop 2>/dev/null

    # D. Drop Bogus TCP Options (Botnet Signature)
    # NFT Native: @th (Transport Header), Offset 272 bits (34*8), Length 16 bits.
    nft add rule inet rt_emergency input tcp flags syn @th,272,16 0x40 drop 2>/dev/null

    # E. Enforce Dynamic Blacklist
    # If source IP is in 'flooders', drop immediately.
    nft add rule inet rt_emergency input ip saddr @flooders drop 2>/dev/null

    # F. Rate Limit & Punishment
    # Relaxed to 100/second to match Global Auto-Tuner defaults.
    nft add rule inet rt_emergency input tcp flags syn limit rate 100/second burst 150 packets add @flooders { ip saddr } 2>/dev/null

    print "    > [Layer A] NFTables RT rules active."
fi

# 3. LAYER B: Legacy IPtables (If available)
# We execute this EVEN IF nft was found. This creates a redundant shield.
# If the user flushes nftables but forgets iptables, these rules still hold.
if command -v iptables >/dev/null 2>&1; then
    print "    > [Layer B] IPtables binary found. Applying LEGACY signatures..."
    
    # 1. Malformed Headers
    iptables -A INPUT -p tcp --syn -m u32 --u32 "0xc&0x000F0000>>16=0x5" -j DROP > /dev/null 2>&1
    
    # 2. Bogus TCP Options
    iptables -A INPUT -p tcp --syn -m u32 --u32 "0x22&0xFFFF=0x40" -j DROP > /dev/null 2>&1
    
    print "    > [Layer B] IPtables RT rules active."
fi
# ==============================================================================

# [FIX] Added missing Stress Engine installation block
print "    Installing Revolutionary Technology pre-install scripts..."
mkdir -p -m 0755 /usr/local/include/csf/pre.d/
cp -avf stressengine.sh /usr/local/include/csf/pre.d/
chmod -v 700 /usr/local/include/csf/pre.d/*.sh
# ==============================================================================

if [ -e "/etc/csf/alert.txt" ]; then
	sh migratedata.sh
fi

# Use generic config
if [ ! -e "/etc/csf/csf.conf" ]; then
	cp -avf csf.generic.conf /etc/csf/csf.conf
fi

if [ ! -d /var/lib/csf ]; then
	mkdir -v -p -m 0600 /var/lib/csf
fi
if [ ! -d /usr/local/csf/lib ]; then
	mkdir -v -p -m 0600 /usr/local/csf/lib
fi
if [ ! -d /usr/local/csf/bin ]; then
	mkdir -v -p -m 0600 /usr/local/csf/bin
fi
if [ ! -d /usr/local/csf/tpl ]; then
	mkdir -v -p -m 0600 /usr/local/csf/tpl
fi

if [ ! -e "/etc/csf/csf.allow" ]; then
	cp -avf csf.generic.allow /etc/csf/csf.allow
fi

# --- [UPDATED] Add Google ASNs to csf.allow ---
print "    Adding Google ASNs to /etc/csf/csf.allow..."

# We use grep -q to avoid adding duplicate entries on re-installation
grep -q "ASN:15169" /etc/csf/csf.allow || echo "ASN:15169 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:36040" /etc/csf/csf.allow || echo "ASN:36040 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:43515" /etc/csf/csf.allow || echo "ASN:43515 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:36561" /etc/csf/csf.allow || echo "ASN:36561 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:19527" /etc/csf/csf.allow || echo "ASN:19527 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:139070" /etc/csf/csf.allow || echo "ASN:139070 # Google ASN" >> /etc/csf/csf.allow
grep -q "ASN:396982" /etc/csf/csf.allow || echo "ASN:396982 # Google ASN" >> /etc/csf/csf.allow
# --- [UPDATED] End Google ASN Block ---

# ... (Standard files copy logic follows) ...

# ... (Skipping middle section to focus on the end) ...

# Execute Stress Engine immediately at the end
print "    > Engaging Stress Engine..."
sh /usr/local/include/csf/pre.d/stressengine.sh

# ... (End of script) ...