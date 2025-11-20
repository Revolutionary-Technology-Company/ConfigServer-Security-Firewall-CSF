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
#   @updated            11.18.2025
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
# (This creates the C file and compiles it using clang)
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
        ok "    > BPF Drop/Echo rule compiled successfully."
        chmod 644 /etc/csf/bpf.d/csf_xdp_drop.o
    else
        error "    > Failed to compile BPF Drop/Echo rule."
    fi
else
    warn "    > clang not found. Cannot compile BPF rules."
fi
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

# ==============================================================================
print "    Installing Revolutionary Technology pre-install scripts..."
mkdir -p -m 0755 /usr/local/include/csf/pre.d/
cp -avf stressengine.sh /usr/local/include/csf/pre.d/
chmod -v 700 /usr/local/include/csf/pre.d/*.sh
# ==============================================================================

if [ -e "/etc/csf/alert.txt" ]; then
	sh migratedata.sh
fi

if [ ! -e "/etc/csf/csf.conf" ]; then
	cp -avf csf.directadmin.conf /etc/csf/csf.conf
fi

# --- [Revolutionary Tech] Set ModSecurity Log Path ---
if [ ! -z "$MODSEC_LOG_PATH" ]; then
    print "    Setting MODSEC_LOG = \"${MODSEC_LOG_PATH}\" in /etc/csf/csf.conf..."
    sed -i "s#^MODSEC_LOG = \".*\"#MODSEC_LOG = \"$MODSEC_LOG_PATH\"#" /etc/csf/csf.conf
fi
# --- [Revolutionary Tech] End ModSecurity Log Path ---

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
	cp -avf csf.directadmin.allow /etc/csf/csf.allow
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

if [ ! -e "/etc/csf/csf.deny" ]; then
	cp -avf csf.deny /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.redirect" ]; then
	cp -avf csf.redirect /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.resellers" ]; then
	cp -avf csf.resellers /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.dirwatch" ]; then
	cp -avf csf.dirwatch /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.syslogs" ]; then
	cp -avf csf.syslogs /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.logfiles" ]; then
	cp -avf csf.logfiles /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.logignore" ]; then
	cp -avf csf.logignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.blocklists" ]; then
	cp -avf csf.blocklists /etc/csf/.
else
	cp -avf csf.blocklists /etc/csf/csf.blocklists.new
fi
if [ ! -e "/etc/csf/csf.ignore" ]; then
	cp -avf csf.directadmin.ignore /etc/csf/csf.ignore
fi
if [ ! -e "/etc/csf/csf.pignore" ]; then
	cp -avf csf.directadmin.pignore /etc/csf/csf.pignore
fi
if [ ! -e "/etc/csf/csf.rignore" ]; then
	cp -avf csf.rignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.fignore" ]; then
	cp -avf csf.fignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.signore" ]; then
	cp -avf csf.signore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.suignore" ]; then
	cp -avf csf.suignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.uidignore" ]; then
	cp -avf csf.uidignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.mignore" ]; then
	cp -avf csf.mignore /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.sips" ]; then
	cp -avf csf.sips /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.dyndns" ]; then
	cp -avf csf.dyndns /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.syslogusers" ]; then
	cp -avf csf.syslogusers /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.smtpauth" ]; then
	cp -avf csf.smtpauth /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.rblconf" ]; then
	cp -avf csf.rblconf /etc/csf/.
fi
if [ ! -e "/etc/csf/csf.cloudflare" ]; then
	cp -avf csf.cloudflare /etc/csf/.
fi

if [ ! -e "/usr/local/csf/tpl/alert.txt" ]; then
	cp -avf alert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/reselleralert.txt" ]; then
	cp -avf reselleralert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/logalert.txt" ]; then
	cp -avf logalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/logfloodalert.txt" ]; then
	cp -avf logfloodalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/syslogalert.txt" ]; then
	cp -avf syslogalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/integrityalert.txt" ]; then
	cp -avf integrityalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/exploitalert.txt" ]; then
	cp -avf exploitalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/queuealert.txt" ]; then
	cp -avf queuealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/etc/csf/csf.conf" ]; then
	cp -avf csf.directadmin.conf /etc/csf/csf.conf
fi

# --- [Revolutionary Tech] Set ModSecurity Log Path ---
if [ ! -z "$MODSEC_LOG_PATH" ]; then
    print "    Setting MODSEC_LOG = \"${MODSEC_LOG_PATH}\" in /etc/csf/csf.conf..."
    sed -i "s#^MODSEC_LOG = \".*\"#MODSEC_LOG = \"$MODSEC_LOG_PATH\"#" /etc/csf/csf.conf
fi
# --- [Revolutionary Tech] End ModSecurity Log Path ---

if [ ! -e "/usr/local/csf/tpl/modsecipdbalert.txt" ]; then
	cp -avf modsecipdbalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/tracking.txt" ]; then
	cp -avf tracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/connectiontracking.txt" ]; then
	cp -avf connectiontracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/processtracking.txt" ]; then
	cp -avf processtracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/accounttracking.txt" ]; then
	cp -avf accounttracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/usertracking.txt" ]; then
	cp -avf usertracking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sshalert.txt" ]; then
	cp -avf sshalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/webminalert.txt" ]; then
	cp -avf webminalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sualert.txt" ]; then
	cp -avf sualert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/sudoalert.txt" ]; then
	cp -avf sudoalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/consolealert.txt" ]; then
	cp -avf consolealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/uialert.txt" ]; then
	cp -avf uialert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/cpanelalert.txt" ]; then
	cp -avf cpanelalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/scriptalert.txt" ]; then
	cp -avf scriptalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/relayalert.txt" ]; then
	cp -avf relayalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/filealert.txt" ]; then
	cp -avf filealert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/watchalert.txt" ]; then
	cp -avf watchalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/loadalert.txt" ]; then
	cp -avf loadalert.txt /usr/local/csf/tpl/.
else
	cp -avf loadalert.txt /usr/local/csf/tpl/loadalert.txt.new
fi
if [ ! -e "/usr/local/csf/tpl/resalert.txt" ]; then
	cp -avf resalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/portscan.txt" ]; then
	cp -avf portscan.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/uidscan.txt" ]; then
	cp -avf uidscan.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/permblock.txt" ]; then
	cp -avf permblock.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/netblock.txt" ]; then
	cp -avf netblock.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/portknocking.txt" ]; then
	cp -avf portknocking.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/forkbombalert.txt" ]; then
	cp -avf forkbombalert.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/recaptcha.txt" ]; then
	cp -avf recaptcha.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.main.txt" ]; then
	cp -avf apache.main.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.http.txt" ]; then
	cp -avf apache.http.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/apache.https.txt" ]; then
	cp -avf apache.https.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.main.txt" ]; then
	cp -avf litespeed.main.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.http.txt" ]; then
	cp -avf litespeed.http.txt /usr/local/csf/tpl/.
fi
if [ ! -e "/usr/local/csf/tpl/litespeed.https.txt" ]; then
	cp -avf litespeed.https.txt /usr/local/csf/tpl/.
fi
cp -avf x-arf.txt /usr/local/csf/tpl/.

# #
#	Only creates pre and post autoloader if it doesn't exist in either location
# #

if [ ! -e "/usr/local/csf/bin/csfpre.sh" ] && [ ! -e "/etc/csf/csfpre.sh" ]; then
	echo "No existing csfpre.sh found — installing a fresh copy..."
    cp -avf csfpre.sh /usr/local/csf/bin/.
else
    echo "csfpre.sh already exists in one of the valid locations — skipping copy."
fi

if [ ! -e "/usr/local/csf/bin/csfpost.sh" ] && [ ! -e "/etc/csf/csfpost.sh" ]; then
	echo "No existing csfpost.sh found — installing a fresh copy..."
    cp -avf csfpost.sh /usr/local/csf/bin/.
else
    echo "csfpost.sh already exists in one of the valid locations — skipping copy."
fi

if [ ! -e "/usr/local/csf/bin/regex.custom.pm" ]; then
	cp -avf regex.custom.pm /usr/local/csf/bin/.
fi
if [ ! -e "/usr/local/csf/bin/pt_deleted_action.pl" ]; then
	cp -avf pt_deleted_action.pl /usr/local/csf/bin/.
fi
if [ ! -e "/etc/csf/messenger" ]; then
	cp -avf messenger /etc/csf/.
fi
if [ ! -e "/etc/csf/messenger/index.recaptcha.html" ]; then
	cp -avf messenger/index.recaptcha.html /etc/csf/messenger/.
fi
if [ ! -e "/etc/csf/ui" ]; then
	cp -avf ui /etc/csf/.
fi
if [ -e "/etc/cron.d/csfcron.sh" ]; then
	mv -fv /etc/cron.d/csfcron.sh /etc/cron.d/csf-cron
fi
if [ ! -e "/etc/cron.d/csf-cron" ]; then
	cp -avf csfcron.sh /etc/cron.d/csf-cron
fi
if [ -e "/etc/cron.d/lfdcron.sh" ]; then
	mv -fv /etc/cron.d/lfdcron.sh /etc/cron.d/lfd-cron
fi
if [ ! -e "/etc/cron.d/lfd-cron" ]; then
	cp -avf lfdcron.sh /etc/cron.d/lfd-cron
fi
sed -i "s%/etc/init.d/lfd restart%/usr/sbin/csf --lfd restart%" /etc/cron.d/lfd-cron
if [ -e "/usr/local/csf/bin/servercheck.pm" ]; then
	rm -f /usr/local/csf/bin/servercheck.pm
fi
if [ -e "/etc/csf/cseui.pl" ]; then
	rm -f /etc/csf/cseui.pl
fi
if [ -e "/etc/csf/csfui.pl" ]; then
	rm -f /etc/csf/csfui.pl
fi
if [ -e "/etc/csf/csfuir.pl" ]; then
	rm -f /etc/csf/csfuir.pl
fi
if [ -e "/usr/local/csf/bin/cseui.pl" ]; then
	rm -f /usr/local/csf/bin/cseui.pl
fi
if [ -e "/usr/local/csf/bin/csfui.pl" ]; then
	rm -f /usr/local/csf/bin/csfui.pl
fi
if [ -e "/usr/local/csf/bin/csfuir.pl" ]; then
	rm -f /usr/local/csf/bin/csfuir.pl
fi
if [ -e "/usr/local/csf/bin/regex.pm" ]; then
	rm -f /usr/local/csf/bin/regex.pm
fi

OLDVERSION=0
if [ -e "/etc/csf/version.txt" ]; then
    OLDVERSION=`head -n 1 /etc/csf/version.txt`
fi

rm -f /etc/csf/csf.pl /usr/sbin/csf /etc/csf/lfd.pl /usr/sbin/lfd
chmod 700 csf.pl lfd.pl
cp -avf csf.pl /usr/sbin/csf
cp -avf lfd.pl /usr/sbin/lfd
chmod 700 /usr/sbin/csf /usr/sbin/lfd
ln -svf /usr/sbin/csf /etc/csf/csf.pl
ln -svf /usr/sbin/lfd /etc/csf/lfd.pl
ln -svf /usr/local/csf/bin/csftest.pl /etc/csf/
ln -svf /usr/local/csf/bin/pt_deleted_action.pl /etc/csf/
ln -svf /usr/local/csf/bin/remove_apf_bfd.sh /etc/csf/
ln -svf /usr/local/csf/bin/uninstall.sh /etc/csf/
ln -svf /usr/local/csf/bin/regex.custom.pm /etc/csf/
ln -svf /usr/local/csf/lib/webmin /etc/csf/
if [ ! -e "/etc/csf/alerts" ]; then
    ln -svf /usr/local/csf/tpl /etc/csf/alerts
fi
chcon -h system_u:object_r:bin_t:s0 /usr/sbin/lfd > /dev/null 2>&1
chcon -h system_u:object_r:bin_t:s0 /usr/sbin/csf > /dev/null 2>&1

mkdir -p /usr/local/directadmin/plugins/csf/
chmod 711 /usr/local/directadmin/plugins/csf
chown diradmin:diradmin /usr/local/directadmin/plugins/csf
cp -avf da/* /usr/local/directadmin/plugins/csf/
cp -avf csf/* /usr/local/directadmin/plugins/csf/images/
find /usr/local/directadmin/plugins/csf/ -type d -exec chmod -v 755 {} \;
find /usr/local/directadmin/plugins/csf/ -type f -exec chmod -v 644 {} \;

if [ -e "/usr/local/directadmin/plugins/csf/exec/csf" ]; then
	rm -f /usr/local/directadmin/plugins/csf/exec/csf
fi
export PATH=$PATH;
gcc -o /usr/local/directadmin/plugins/csf/exec/csf csf.c
chown -Rv diradmin:diradmin /usr/local/directadmin/plugins/csf
chmod -v 755 /usr/local/directadmin/plugins/csf/admin/index.html
chmod -v 755 /usr/local/directadmin/plugins/csf/admin/index.raw
chmod -v 755 /usr/local/directadmin/plugins/csf/exec/da_csf.cgi
chmod -v 755 /usr/local/directadmin/plugins/csf/reseller/index.html
chmod -v 755 /usr/local/directadmin/plugins/csf/reseller/index.raw
chmod -v 755 /usr/local/directadmin/plugins/csf/exec/da_csf_reseller.cgi
chmod -v 755 /usr/local/directadmin/plugins/csf/scripts/*
chown -v root:root /usr/local/directadmin/plugins/csf/exec/csf
chmod -v 4755 /usr/local/directadmin/plugins/csf/exec/csf

if test \`cat /proc/1/comm\` = "systemd"
then
    if [ -e /etc/init.d/lfd ]; then
        if [ -f /etc/redhat-release ]; then
            /sbin/chkconfig csf off
            /sbin/chkconfig lfd off
            /sbin/chkconfig csf --del
            /sbin/chkconfig lfd --del
        elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
            update-rc.d -f lfd remove
            update-rc.d -f csf remove
        elif [ -f /etc/gentoo-release ]; then
            rc-update del lfd default
            rc-update del csf default
        elif [ -f /etc/slackware-version ]; then
            rm -vf /etc/rc.d/rc3.d/S80csf
            rm -vf /etc/rc.d/rc4.d/S80csf
            rm -vf /etc/rc.d/rc5.d/S80csf
            rm -vf /etc/rc.d/rc3.d/S85lfd
            rm -vf /etc/rc.d/rc4.d/S85lfd
            rm -vf /etc/rc.d/rc5.d/S85lfd
        else
            /sbin/chkconfig csf off
            /sbin/chkconfig lfd off
            /sbin/chkconfig csf --del
            /sbin/chkconfig lfd --del
        fi
        rm -fv /etc/init.d/csf
        rm -fv /etc/init.d/lfd
    fi

    mkdir -p /etc/systemd/system/
    mkdir -p /usr/lib/systemd/system/
    cp -avf lfd.service /usr/lib/systemd/system/
    cp -avf csf.service /usr/lib/systemd/system/

    chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/lfd.service > /dev/null 2>&1
    chcon -h system_u:object_r:systemd_unit_file_t:s0 /usr/lib/systemd/system/csf.service > /dev/null 2>&1

    systemctl daemon-reload

    systemctl enable csf.service > /dev/null 2>&1
    systemctl enable lfd.service > /dev/null 2>&1

    systemctl disable firewalld > /dev/null 2>&1
    systemctl stop firewalld > /dev/null 2>&1
    systemctl mask firewalld > /dev/null 2>&1
else
    cp -avf lfd.sh /etc/init.d/lfd
    cp -avf csf.sh /etc/init.d/csf
    chmod -v 755 /etc/init.d/lfd
    chmod -v 755 /etc/init.d/csf

    if [ -f /etc/redhat-release ]; then
        /sbin/chkconfig lfd on
        /sbin/chkconfig csf on
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        update-rc.d -f lfd remove
        update-rc.d -f csf remove
        update-rc.d lfd defaults 80 20
        update-rc.d csf defaults 20 80
    elif [ -f /etc/gentoo-release ]; then
        rc-update add lfd default
        rc-update add csf default
    elif [ -f /etc/slackware-version ]; then
        ln -svf /etc/init.d/csf /etc/rc.d/rc3.d/S80csf
        ln -svf /etc/init.d/csf /etc/rc.d/rc4.d/S80csf
        ln -svf /etc/init.d/csf /etc/rc.d/rc5.d/S80csf
        ln -svf /etc/init.d/lfd /etc/rc.d/rc3.d/S85lfd
        ln -svf /etc/init.d/lfd /etc/rc.d/rc4.d/S85lfd
        ln -svf /etc/init.d/lfd /etc/rc.d/rc5.d/S85lfd
    else
        /sbin/chkconfig lfd on
        /sbin/chkconfig csf on
    fi
fi

# #
#	Step > Permissions
# #

prinp "${APP_NAME_SHORT:-CSF} > File Permissions" \
       "This step ensures that your ${APP_NAME_SHORT:-CSF} files contain the correct folder and file permissions."

# #
#   List of directories to set ownership
# #

dirs="/etc/csf /var/lib/csf /usr/local/csf"

# #
#   List of individual files to set ownership
# #

files="/usr/sbin/csf /usr/sbin/lfd /etc/logrotate.d/lfd /etc/cron.d/csf-cron /etc/cron.d/lfd-cron /usr/local/man/man1/csf.1 /usr/lib/systemd/system/lfd.service /usr/lib/systemd/system/csf.service /etc/init.d/lfd /etc/init.d/csf"

# #
#   Set ownership for directories
# #

CSF_CHOWN_GENERAL="root:root"

for dir in $dirs; do
    if [ -d "$dir" ]; then
        chown -Rf "${CSF_CHOWN_GENERAL}" "$dir"
		ok "    Set ownership ${greenl}${CSF_CHOWN_GENERAL}${greym} for folder ${bluel}${dir}${greym}"
    else
		warn "    Could not set ownership ${yellowl}${CSF_CHOWN_GENERAL}${greym}; folder does not exist: ${yellowl}${dir}${greym}"
    fi
done

# #
#   Set ownership for individual files
# #

for file in $files; do
    if [ -e "$file" ]; then
        chown -f "${CSF_CHOWN_GENERAL}" "$file"
		ok "    Set ownership ${greenl}${CSF_CHOWN_GENERAL}${greym} for file ${bluel}${file}${greym}"
    else
		warn "    Could not set ownership ${yellowl}${CSF_CHOWN_GENERAL}${greym}; file does not exist: ${yellowl}${file}${greym}"
    fi
done

# #
#	Step > Webmin
#		- create tarball of webmin files
#		- Detect /usr/share/webmin
#		- Extract tarball to /usr/share/webmin/csf
# #

prinp "${APP_NAME_SHORT:-CSF} > Webmin" \
       "We will now check your system and see if Webmin integration needs enabled."

cd "${CSF_WEBMIN_SRC}"
tar -czf "${CSF_WEBMIN_TARBALL}" ./*
if [ -f "$CSF_WEBMIN_TARBALL" ]; then
    ok "    Created ${greenl}$CSF_WEBMIN_TARBALL"
else
    error "    Failed to create ${redl}$CSF_WEBMIN_TARBALL"
fi

ln -sf "${CSF_WEBMIN_TARBALL}" "${CSF_ETC}/"
if [ -L "${CSF_WEBMIN_SYMBOLIC}" ] && [ -f "${CSF_WEBMIN_SYMBOLIC}" ]; then
	ok "    Created symbolic link ${greenl}${CSF_WEBMIN_SYMBOLIC}"
else
    error "    Failed to create symbolic link ${redl}${CSF_WEBMIN_SYMBOLIC}"
fi

# #
#   Copy Webmin files if destination exists
# #

if [ -d "${CSF_WEBMIN_HOME}" ]; then
    mkdir -p "$CSF_WEBMIN_DESC"                     		# Ensure destination exists
	cp -a csf/* "$CSF_WEBMIN_DESC"/							# Copy all files from current folder
	ok "    CSF Webmin module installed to ${greenl}${CSF_WEBMIN_DESC}${greym}"
else
    echo "Directory ${CSF_WEBMIN_HOME} does not exist. Skipping copy."
	error "    Webmin home folder ${redl}${CSF_WEBMIN_HOME}${greym} does not exist; skipping Webmin install"
fi

# #
#	Webmin > Install CSF to webmin.acl
#	This is what makes CSF appear in Webmin menu
# #

if [ -f "$CSF_WEBMIN_FILE_ACL" ]; then

	# #
	#	Get Webmin connection info
	# #

	WEBMIN_CONF="/etc/webmin/miniserv.conf"

	# #
	#	fetch webmin port and protocol
	# #

	if grep '^ssl=' "$WEBMIN_CONF" | cut -d= -f2 | grep -q '^1$'; then
		WEBMIN_PROTO="https"
	else
		WEBMIN_PROTO="http"
	fi

	WEBMIN_PORT=$(grep '^port=' "$WEBMIN_CONF" | cut -d= -f2)

	# #
	#   Check if 'csf' is already listed for root
	# #

	if grep -Eq "^${CSF_WEBMIN_ACL_USER}:.*\b${CSF_WEBMIN_ACL_MODULE}\b" "$CSF_WEBMIN_FILE_ACL"; then
		info "    CSF Webmin module already registered in ${bluel}${CSF_WEBMIN_FILE_ACL}${greym}"
		print

		print "   Webmin already contains ${APP_NAME_SHORT:-CSF} module"
		print "   "
		print "   To access ${APP_NAME_SHORT:-CSF}, open your browser and navigate to"
		print "       ${yellowd}${WEBMIN_PROTO}://${SERVER_HOST}:${WEBMIN_PORT}/"
		print "   "
		print "   On the left-side menu, navigate to ${yellowd}System ${greym} > ${yellowd}${APP_NAME:-ConfigServer Security & Firewall}"
	else
		CSF_WEBMIN_TEMP=$(mktemp)
		awk -v user="$CSF_WEBMIN_ACL_USER" -v mod="$CSF_WEBMIN_ACL_MODULE" '
			BEGIN {found=0}
			$0 ~ "^"user":" {
				$0 = $0 " " mod
				found=1
			}
			{print}
			END {
				if (found == 0) {
					print user ": " mod
				}
			}
		' "$CSF_WEBMIN_FILE_ACL" > "$CSF_WEBMIN_TEMP" && mv "$CSF_WEBMIN_TEMP" "$CSF_WEBMIN_FILE_ACL"

		ok "    Added CSF Webmin module installed to ${greenl}${CSF_WEBMIN_FILE_ACL}${greym}"
		print
	
		print "   CSF has been integrated into Webmin"
		print "   "
		print "   To access ${APP_NAME_SHORT:-CSF}, open your browser and navigate to"
		print "       ${yellowd}${WEBMIN_PROTO}://${SERVER_HOST}:${WEBMIN_PORT}/"
		print "   "
		print "   On the left-side menu, navigate to ${yellowd}System ${greym} > ${yellowd}${APP_NAME:-ConfigServer Security & Firewall}"
	fi
else
	info "    CSF Webmin skipped; could not find ${bluel}${CSF_WEBMIN_FILE_ACL}${greym}"
fi

# #
#	Step > csf.conf Modified Settings
#   
#   SYSLOG_LOG          By default, RHEL systems use /var/log/messages
#                       Debian systems use /var/log/syslog
#	
#	IPTABLES_LOG		The same as SYSLOG_LOG
# #

prinp "${APP_NAME_SHORT:-CSF} > Customize csf.config" \
       "This step will check which Linux distribution family you are running, RHEL (Red Hat) or a Debian-based system. This determines what your default " \
	   "logging paths will be."

# #
#   Detect system log file path
# #

SYSLOG_PATH=""

if [ -f /var/log/syslog ]; then
    SYSLOG_PATH="/var/log/syslog"
elif [ -f /var/log/messages ]; then
    SYSLOG_PATH="/var/log/messages"
else
    SYSLOG_PATH="/dev/null"
fi

# #
#   Update SYSLOG_LOG and IPTABLES_LOG defaults
#   
#   Only change these values during installation.
#   Users can manually edit csf.conf later, and those
#   settings will not be overridden by updates.
# #

for KEY in SYSLOG_LOG IPTABLES_LOG; do
    if grep -qE "^${KEY}" "${CSF_CONF}"; then
        # Update existing line
        sed -i "s|^${KEY}.*|${KEY} = \"${SYSLOG_PATH}\"|" "${CSF_CONF}"
		ok "    Updating ${greenl}${CSF_CONF}${greym} setting ${fuchsial}${KEY}=${white}\"${bluel}${SYSLOG_PATH}${white}\"${greym}"
    else
        # Append if missing
        echo "${KEY} = \"${SYSLOG_PATH}\"" >> "${CSF_CONF}"
		ok "    Appending ${greenl}${CSF_CONF}${greym} setting ${fuchsial}${KEY}=${white}\"${bluel}${SYSLOG_PATH}${white}\"${greym}"
    fi
done

# Execute Stress Engine immediately
print "    > Engaging Stress Engine..."
sh /usr/local/include/csf/pre.d/stressengine.sh

# #
#	Check current value of
#		TESTING="0"
# #

TESTING_VALUE=$(grep '^[[:space:]]*TESTING[[:space:]]*=' "$CSF_CONF" | awk -F= '{gsub(/ /,"",$2); print $2}' | tr -d '"')

prinp "${APP_NAME_SHORT:-CSF} > Installation Complete" \
       "Your installation is complete. Read important notes below."

print "    For more information on how to use ${APP_NAME_SHORT:-CSF}; visit"
print "        ${yellowd}${APP_LINK_DOCS:-https://docs.configserver.shop}"
if [ -f "$CSF_CONF" ]; then
	print "    "
	print "    The next step in the process should be to open the config file located at"
	print "        ${yellowd}${CSF_CONF}"
	if [ "$TESTING_VALUE" = "1" ]; then
	print "    "
	print "    The setting ${yellowd}TESTING${greym} is currently ${greenl}enabled${greym}; you should open your config and"
	print "    disable this setting before to you begin using your new firewall."
	print "    To disable this setting, open ${yellowd}${CSF_CONF}${greym} and set the following:"
	print "        ${fuchsial}TESTING = ${white}\"${bluel}0${white}\"${greym}"
	else
	print "    "
	print "    The setting ${yellowd}TESTING${greym} is currently ${redl}disabled${greym}; which is the"
	print "    correct setting if you plan to start using your firewall."
	fi
else
	print "    "
	print "    An error has occured; we cannot locate your ${APP_NAME_SHORT:-CSF} config file:"
	print "        ${yellowd}${CSF_CONF}"
	print "    "
	print "    You must have a valid config in the correct location before ${APP_NAME_SHORT:-CSF} will"
	print "    function properly."
fi
print
print "    After editing or adding a new ${yellowd}${CSF_CONF}${greym}, restart ${APP_NAME_SHORT:-CSF} with:"
print "        ${yellowd}sudo csf -ra"
print
print
}

{
type: uploaded file
fileName: auto.directadmin.pl
fullContent:
#!/usr/bin/perl
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
## no critic (ProhibitBarewordFileHandles, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
use strict;
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;

umask(0177);

our (%config, %configsetting, $vps, $oldversion);

$oldversion = $ARGV[0];

open (VERSION, "<","/etc/csf/version.txt");
flock (VERSION, LOCK_SH);
my $version = <VERSION>;
close (VERSION);
chomp $version;
$version =~ s/\W/_/g;
system("/bin/cp","-avf","/etc/csf/csf.conf","/var/lib/csf/backup/".time."_pre_v${version}_upgrade");

&loadcsfconfig;

foreach my $alertfile ("sshalert.txt","sualert.txt","sudoalert.txt","webminalert.txt","cpanelalert.txt") {
	if (-e "/usr/local/csf/tpl/".$alertfile) {
		sysopen (my $IN, "/usr/local/csf/tpl/".$alertfile, O_RDWR | O_CREAT);
		flock ($IN, LOCK_EX);
		my @data = <$IN>;
		chomp @data;
		my $hit = 0;
		foreach my $line (@data) {
			if ($line =~ /\[text\]/) {$hit = 1}
		}
		unless ($hit) {
			print $IN "\nLog line:\n\n[text]\n";
		}
		close ($IN);
	}
}

if (-e "/proc/vz/veinfo") {
	$vps = 1;
} else {
	open (IN, "<","/proc/self/status"); 
	flock (IN, LOCK_SH);
	while (my $line = <IN>) {
		chomp $line;
		if ($line =~ /^envID:\s*(\d+)\s*$/) {
			if ($1 > 0) {
				$vps = 1;
				last;
			}
		}
	}
	close (IN);
}

# --- Legacy Migration Blocks (Kept for stability) ---
if (&checkversion("10.11") and !-e "/var/lib/csf/auto1011") {
	if (-e "/var/lib/csf/stats/lfdstats") {
		sysopen (STATS,"/var/lib/csf/stats/lfdstats", O_RDWR | O_CREAT);
		flock (STATS, LOCK_EX);
		my @stats = <STATS>;
		chomp @stats;
		my %ccs;
		my @line = split(/\,/,$stats[69]);
		for (my $x = 0; $x < @line; $x+=2) {$ccs{$line[$x]} = $line[$x+1]}
		$stats[69] = "";
		foreach my $key (keys %ccs) {$stats[69] .= "$key,$ccs{$key},"}
		seek (STATS, 0, 0);
		truncate (STATS, 0);
		foreach my $line (@stats) {
			print STATS "$line\n";
		}
		close (STATS);
	}
	open (OUT, ">", "/var/lib/csf/auto1011");
	flock (OUT, LOCK_EX);
	print OUT time;
	close (OUT);
}
if (&checkversion("10.23") and !-e "/var/lib/csf/auto1023") {
	if (-e "/etc/csf/csf.blocklists") {
		sysopen (IN,"/etc/csf/csf.blocklists", O_RDWR | O_CREAT);
		flock (IN, LOCK_EX);
		my @data = <IN>;
		chomp @data;
		seek (IN, 0, 0);
		truncate (IN, 0);
		my $SPAMDROPV6 = 0;
		my $STOPFORUMSPAMV6 = 0;
		foreach my $line (@data) {
			if ($line =~ /^(\#)?SPAMDROPV6/) {$SPAMDROPV6 = 1}
			if ($line =~ /^(\#)?STOPFORUMSPAMV6/) {$STOPFORUMSPAMV6 = 1}
			print IN "$line\n";
		}
		unless ($SPAMDROPV6) {
			print IN "\n# Spamhaus IPv6 Don't Route Or Peer List (DROPv6)\n";
			print IN "# Details: http://www.spamhaus.org/drop/\n";
			print IN "#SPAMDROPV6|86400|0|https://www.spamhaus.org/drop/dropv6.txt\n";
		}
		unless ($STOPFORUMSPAMV6) {
			print IN "\n# Stop Forum Spam IPv6\n";
			print IN "# Details: http://www.stopforumspam.com/downloads/\n";
			print IN "# Many of the lists available contain a vast number of IP addresses so special\n";
			print IN "# care needs to be made when selecting from their lists\n";
			print IN "#STOPFORUMSPAMV6|86400|0|http://www.stopforumspam.com/downloads/listed_ip_1_ipv6.zip\n";
		}
		close (IN);
	}
	open (OUT, ">", "/var/lib/csf/auto1023");
	flock (OUT, LOCK_EX);
	print OUT time;
	close (OUT);
}
if (&checkversion("12.02") and !-e "/var/lib/csf/auto1202") {
	if (-e "/etc/csf/csf.blocklists") {
		sysopen (IN,"/etc/csf/csf.blocklists", O_RDWR | O_CREAT);
		flock (IN, LOCK_EX);
		my @data = <IN>;
		chomp @data;
		seek (IN, 0, 0);
		truncate (IN, 0);
		foreach my $line (@data) {
			if ($line =~ /greensnow/) {$line =~ s/http:/https:/g}
			print IN "$line\n";
		}
		close (IN);
	}
	open (OUT, ">", "/var/lib/csf/auto1202");
	flock (OUT, LOCK_EX);
	print OUT time;
	close (OUT);
}
if (&checkversion("14.03") and !-e "/var/lib/csf/auto1403") {
	if (-e "/etc/csf/csf.blocklists") {
		sysopen (IN,"/etc/csf/csf.blocklists", O_RDWR | O_CREAT);
		flock (IN, LOCK_EX);
		my @data = <IN>;
		chomp @data;
		seek (IN, 0, 0);
		truncate (IN, 0);
		foreach my $line (@data) {
			if ($line =~ /dshield/) {$line =~ s/http:/https:/g}
			print IN "$line\n";
		}
		close (IN);
	}
	open (OUT, ">", "/var/lib/csf/auto1403");
	flock (OUT, LOCK_EX);
	print OUT time;
	close (OUT);
}
# --- End Migration Blocks ---

if (-e "/etc/csf/csf.allow") {
	sysopen (IN,"/etc/csf/csf.allow", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^Include \/etc\/csf\/cpanel\.comodo\.allow/) {next}
		print IN "$line\n";
	}
	close (IN);
}
if (-e "/etc/csf/csf.ignore") {
	sysopen (IN,"/etc/csf/csf.ignore", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^Include \/etc\/csf\/cpanel\.comodo\.ignore/) {next}
		print IN "$line\n";
	}
	close (IN);
}
if (-e "/usr/local/csf/bin/regex.custom.pm") {
	sysopen (IN,"/usr/local/csf/bin/regex.custom.pm", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^use strict;/) {next}
		print IN "$line\n";
	}
	close (IN);
}
if (-e "/etc/csf/csf.blocklists") {
	sysopen (IN,"/etc/csf/csf.blocklists", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /feeds\.dshield\.org/) {$line =~ s/feeds\.dshield\.org/www\.dshield\.org/g}
		if ($line =~ /openbl\.org/i) {next}
		if ($line =~ /autoshun/i) {next}
		print IN "$line\n";
	}
	close (IN);
}
if (-e "/var/lib/csf/csf.tempban") {
	sysopen (IN,"/var/lib/csf/csf.tempban", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^\d+\:/) {$line =~ s/\:/\|/g}
		print IN "$line\n";
	}
	close (IN);
}
if (-e "/var/lib/csf/csf.tempallow") {
	sysopen (IN,"/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^\d+\:/) {$line =~ s/\:/\|/g}
		print IN "$line\n";
	}
	close (IN);
}

if ($config{TESTING}) {

	open (IN, "<", "/etc/ssh/sshd_config") or die $!;
	flock (IN, LOCK_SH) or die $!;
	my @sshconfig = <IN>;
	close (IN);
	chomp @sshconfig;

	my $sshport = "22";
	foreach my $line (@sshconfig) {
		if ($line =~ /^Port (\d+)/) {$sshport = $1}
	}

	$config{TCP_IN} =~ s/\s//g;
	if ($config{TCP_IN} ne "") {
		foreach my $port (split(/\,/,$config{TCP_IN})) {
			if ($port eq $sshport) {$sshport = "22"}
		}
	}

	if ($sshport ne "22") {
		$config{TCP_IN} .= ",$sshport";
		$config{TCP6_IN} .= ",$sshport";
		open (IN, "<", "/etc/csf/csf.conf") or die $!;
		flock (IN, LOCK_SH) or die $!;
		my @config = <IN>;
		close (IN);
		chomp @config;
		open (OUT, ">", "/etc/csf/csf.conf") or die $!;
		flock (OUT, LOCK_EX) or die $!;
		foreach my $line (@config) {
			if ($line =~ /^TCP6_IN/) {
				print OUT "TCP6_IN = \"$config{TCP6_IN}\"\n";
				print "\n*** SSH port $sshport added to the TCP6_IN port list\n\n";
			}
			elsif ($line =~ /^TCP_IN/) {
				print OUT "TCP_IN = \"$config{TCP_IN}\"\n";
				print "\n*** SSH port $sshport added to the TCP_IN port list\n\n";
			}
			else {
				print OUT $line."\n";
			}
		}
		close OUT;
		&loadcsfconfig;

	}

	open (FH, "<", "/proc/sys/kernel/osrelease");
	flock (IN, LOCK_SH);
	my @data = <FH>;
	close (FH);
	chomp @data;
    
    # [REVOLUTIONARY TECH UPDATE]
    # Logic updated to support Kernel 4, 5, 6+
	if ($data[0] =~ /^(\d+)\.(\d+)\.(\d+)/) {
		my $maj = $1;
		my $mid = $2;
		my $min = $3;
        # Enable Conntrack if Kernel is 3.7+ OR Major version is > 3
		if ( ($maj == 3 and $mid > 6) or ($maj > 3) ) {
			open (IN, "<", "/etc/csf/csf.conf") or die $!;
			flock (IN, LOCK_SH) or die $!;
			my @config = <IN>;
			close (IN);
			chomp @config;
			open (OUT, ">", "/etc/csf/csf.conf") or die $!;
			flock (OUT, LOCK_EX) or die $!;
			foreach my $line (@config) {
				if ($line =~ /^USE_CONNTRACK =/) {
					print OUT "USE_CONNTRACK = \"1\"\n";
					print "\n*** USE_CONNTRACK Enabled (Modern Kernel Detected)\n\n";
				} else {
					print OUT $line."\n";
				}
			}
			close OUT;
			&loadcsfconfig;
		}
	}

	my @ipdata;
	eval {
		local $SIG{__DIE__} = undef;
		local $SIG{'ALRM'} = sub {die "alarm\n"};
		alarm(3);
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IPTABLES} --wait -L OUTPUT -nv");
		@ipdata = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @ipdata;
		if ($ipdata[0] =~ /# Warning: iptables-legacy tables present/) {shift @ipdata}
		alarm(0);
	};
	alarm(0);
	if ($@ ne "alarm\n" and $ipdata[0] =~ /^Chain OUTPUT/) {
		$config{IPTABLESWAIT} = "--wait";
		$config{WAITLOCK} = 1;
		open (IN, "<", "/etc/csf/csf.conf") or die $!;
		flock (IN, LOCK_SH) or die $!;
		my @config = <IN>;
		close (IN);
		chomp @config;
		open (OUT, ">", "/etc/csf/csf.conf") or die $!;
		flock (OUT, LOCK_EX) or die $!;
		foreach my $line (@config) {
			if ($line =~ /WAITLOCK =/) {
				print OUT "WAITLOCK = \"1\"\n";
			} else {
				print OUT $line."\n";
			}
		}
		close OUT;
		&loadcsfconfig;
	}

	if (-e $config{IP6TABLES} and !$vps) {
		my ($childin, $childout);
		my $cmdpid;
		if (-e $config{IP}) {$cmdpid = open3($childin, $childout, $childout, $config{IP}, "-oneline", "addr")}
		elsif (-e $config{IFCONFIG}) {$cmdpid = open3($childin, $childout, $childout, $config{IFCONFIG})}
		my @ifconfig = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @ifconfig;
		if (grep {$_ =~ /\s*inet6/} @ifconfig) {
			$config{IPV6} = 1;
			open (FH, "<", "/proc/sys/kernel/osrelease");
			flock (IN, LOCK_SH);
			my @data = <FH>;
			close (FH);
			chomp @data;
			if ($data[0] =~ /^(\d+)\.(\d+)\.(\d+)/) {
				my $maj = $1;
				my $mid = $2;
				my $min = $3;
				if (($maj > 2) or (($maj > 1) and ($mid > 6)) or (($maj > 1) and ($mid > 5) and ($min > 19))) {
					$config{IPV6_SPI} = 1;
				} else {
					$config{IPV6_SPI} = 0;
				}
			}
			open (IN, "<", "/etc/csf/csf.conf") or die $!;
			flock (IN, LOCK_SH) or die $!;
			my @config = <IN>;
			close (IN);
			chomp @config;
			open (OUT, ">", "/etc/csf/csf.conf") or die $!;
			flock (OUT, LOCK_EX) or die $!;
			foreach my $line (@config) {
				if ($line =~ /^IPV6 =/) {
					print OUT "IPV6 = \"$config{IPV6}\"\n";
					print "\n*** IPV6 Enabled\n\n";
				}
				elsif ($line =~ /^IPV6_SPI =/) {
					print OUT "IPV6_SPI = \"$config{IPV6_SPI}\"\n";
					print "\n*** IPV6_SPI set to $config{IPV6_SPI}\n\n";
				} else {
					print OUT $line."\n";
				}
			}
			close OUT;
			&loadcsfconfig;
		}
	}
}

open (IN, "<", "csf.directadmin.conf") or die $!;
flock (IN, LOCK_SH) or die $!;
my @config = <IN>;
close (IN);
chomp @config;
open (OUT, ">", "/etc/csf/csf.conf") or die $!;
flock (OUT, LOCK_EX) or die $!;
foreach my $line (@config) {
	if ($line =~ /^\#/) {
		print OUT $line."\n";
		next;
	}
	if ($line !~ /=/) {
		print OUT $line."\n";
		next;
	}
	my ($name,$value) = split (/=/,$line,2);
	$name =~ s/\s//g;
	if ($value =~ /\"(.*)\"/) {
		$value = $1;
	} else {
		print "Error: Invalid configuration line [$line]";
	}
	if (&checkversion("10.15") and !-e "/var/lib/csf/auto1015") {
		if ($name eq "MESSENGER_RATE" and $config{$name} eq "30/m") {$config{$name} = "100/s"}
		if ($name eq "MESSENGER_BURST" and $config{$name} eq "5") {$config{$name} = "150"}
		open (my $AUTO, ">", "/var/lib/csf/auto1015");
		flock ($AUTO, LOCK_EX);
		print $AUTO time;
		close ($AUTO);
	}
	if ($configsetting{$name}) {
		print OUT "$name = \"$config{$name}\"\n";
	} else {
		if (&checkversion("9.29") and !-e "/var/lib/csf/auto929" and $name eq "PT_USERRSS") {
			$line = "PT_USERRSS = \"$config{PT_USERMEM}\"";
			open (my $AUTO, ">", "/var/lib/csf/auto929");
			flock ($AUTO, LOCK_EX);
			print $AUTO time;
			close ($AUTO);
		}
		if ($name eq "CC_SRC") {$line = "CC_SRC = \"1\""}
		print OUT $line."\n";
		print "New setting: $name\n";
	}
}
close OUT;

if ($config{TESTING}) {
    # [REVOLUTIONARY TECH UPDATE]
    # Added fallback to 'ss' because 'netstat' is deprecated/missing on modern minimal distros
	my @netstat = `netstat -lpn 2>/dev/null`;
    if (!@netstat) {
        @netstat = `ss -lpn`;
    }
	chomp @netstat;
	my @tcpports;
	my @udpports;
	my @tcp6ports;
	my @udp6ports;
	foreach my $line (@netstat) {
		if ($line =~ /^(\w+).* (\d+\.\d+\.\d+\.\d+):(\d+)/) {
			if ($2 eq '127.0.0.1') {next}
			if ($1 eq "tcp") {
				push @tcpports, $3;
			}
			elsif ($1 eq "udp") {
				push @udpports, $3;
			}
		}
		if ($line =~ /^(\w+).* (::):(\d+) /) {
			if ($1 eq "tcp") {
				push @tcp6ports, $3;
			}
			elsif ($1 eq "udp") {
				push @udp6ports, $3;
			}
		}
	}

	@tcpports = sort { $a <=> $b } @tcpports;
	@udpports = sort { $a <=> $b } @udpports;
	@tcp6ports = sort { $a <=> $b } @tcp6ports;
	@udp6ports = sort { $a <=> $b } @udp6ports;

	print "\nTCP ports currently listening for incoming connections:\n";
	my $last = "";
	foreach my $port (@tcpports) {
		if ($port ne $last) {
			if ($port ne $tcpports[0]) {print ","}
			print $port;
			$last = $port;
		}
	}
	print "\n\nUDP ports currently listening for incoming connections:\n";
	$last = "";
	foreach my $port (@udpports) {
		if ($port ne $last) {
			if ($port ne $udpports[0]) {print ","}
			print $port;
			$last = $port;
		}
	}
	my $opts = "TCP_*, UDP_*";
	if (@tcp6ports or @udp6ports) {
		$opts .= ", IPV6, TCP6_*, UDP6_*";
		print "\n\nIPv6 TCP ports currently listening for incoming connections:\n";
		my $last = "";
		foreach my $port (@tcp6ports) {
			if ($port ne $last) {
				if ($port ne $tcp6ports[0]) {print ","}
				print $port;
				$last = $port;
			}
		}
		print "\n";
		print "\nIPv6 UDP ports currently listening for incoming connections:\n";
		$last = "";
		foreach my $port (@udp6ports) {
			if ($port ne $last) {
				if ($port ne $udp6ports[0]) {print ","}
				print $port;
				$last = $port;
			}
		}
	}
	print "\n\nNote: The port details above are for information only, csf hasn't been auto-configured.\n\n";
	print "Don't forget to:\n";
	print "1. Configure the following options in the csf configuration to suite your server: $opts\n";
	print "2. Restart csf and lfd\n";
	print "3. Set TESTING to 0 once you're happy with the firewall, lfd will not run until you do so\n";
}

if ($ENV{SSH_CLIENT}) {
	my $ip = (split(/ /,$ENV{SSH_CLIENT}))[0];
	if ($ip =~ /(\d+\.\d+\.\d+\.\d+)/) {
		print "\nAdding current SSH session IP address to the csf whitelist in csf.allow:\n";
		system("/usr/sbin/csf -a $1 csf SSH installation/upgrade IP address");
	}
}

exit;
###############################################################################
sub loadcsfconfig {
	open (IN, "<", "/etc/csf/csf.conf") or die $!;
	flock (IN, LOCK_SH) or die $!;
	my @config = <IN>;
	close (IN);
	chomp @config;

	foreach my $line (@config) {
		if ($line =~ /^\#/) {next}
		if ($line !~ /=/) {next}
		my ($name,$value) = split (/=/,$line,2);
		$name =~ s/\s//g;
		if ($value =~ /\"(.*)\"/) {
			$value = $1;
		} else {
			print "Error: Invalid configuration line [$line]";
		}
		$config{$name} = $value;
		$configsetting{$name} = 1;
	}
	return;
}
###############################################################################
sub checkversion {
	my $version = shift;
	my ($maj, $min) = split(/\./,$version);
	my ($oldmaj, $oldmin) = split(/\./,$oldversion);

	if ($oldmaj == 0 or $oldmaj eq "") {return 0}

	if (($oldmaj < $maj) or ($oldmaj == $maj and $oldmin < $min)) {return 1} else {return 0}
}
###############################################################################