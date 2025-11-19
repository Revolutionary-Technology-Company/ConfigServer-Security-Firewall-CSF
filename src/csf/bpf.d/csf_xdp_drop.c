// 
// CSF XDP Drop Actions & UDP Whitelist
// Implements high-performance packet handling for common firewall targets.
//
// Targets:
//   DROP   -> XDP_DROP (Silent, immediate drop)
//   ECHO   -> XDP_TX   (Reflect packet back to sender)
//
// Features:
//   1. Dynamic IP Blacklist (Source IP)
//   2. Zero-Trust TCP & UDP Whitelist (Destination Port)
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

// -----------------------------------------------------------------------------
// MAP 1: Blocked IPs (Source IP)
// -----------------------------------------------------------------------------
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);
    __type(value, __u32);
} csf_drop_map SEC(".maps");

// -----------------------------------------------------------------------------
// MAP 2: Allowed UDP Ports (Destination Port)
// -----------------------------------------------------------------------------
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_udp_allow_map SEC(".maps");

// -----------------------------------------------------------------------------
// MAP 3: Allowed TCP Ports (Destination Port) [NEW]
// -----------------------------------------------------------------------------
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_tcp_allow_map SEC(".maps");

// -----------------------------------------------------------------------------
// MAP 4: Configuration Flags [NEW]
// Key 0: RT_UDP_XDP_STRICT (0=Off, 1=On)
// Key 1: RT_TCP_XDP_STRICT (0=Off, 1=On)
// -----------------------------------------------------------------------------
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u32);
} csf_conf_map SEC(".maps");

// Helper to swap addresses for ECHO (Reflect)
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

    // ------------------------------------------------------
    // 1. Check Dynamic Blocklist
    // ------------------------------------------------------
    __u32 src_ip = ip->saddr;
    __u32 *action = bpf_map_lookup_elem(&csf_drop_map, &src_ip);

    if (action) {
        if (*action == 1) { // ECHO
            swap_src_dst(data, eth, ip);
            return XDP_TX;
        }
        return XDP_DROP; // Default DROP
    }

    // ------------------------------------------------------
    // 2. Strict UDP Whitelist
    // ------------------------------------------------------
    if (ip->protocol == IPPROTO_UDP) {
        __u32 key_udp_strict = 0;
        __u32 *udp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_udp_strict);

        // Only enforce if flag is set to 1
        if (udp_strict_flag && *udp_strict_flag == 1) {
            struct udphdr *udp = (void*)ip + sizeof(*ip);
            if ((void*)udp + sizeof(*udp) > data_end) return XDP_PASS;

            __u32 dest_port = bpf_ntohs(udp->dest);
            __u32 *allowed = bpf_map_lookup_elem(&csf_udp_allow_map, &dest_port);

            if (!allowed) return XDP_DROP;
        }
    }

    // ------------------------------------------------------
    // 3. Strict TCP Whitelist [NEW]
    // ------------------------------------------------------
    if (ip->protocol == IPPROTO_TCP) {
        __u32 key_tcp_strict = 1;
        __u32 *tcp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_tcp_strict);

        // Only enforce if flag is set to 1
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