// 
// CSF XDP Drop Actions & Zero Trust Whitelist (FIXED)
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
// MAPS
// -----------------------------------------------------------------------------

// Map 1: Blocked IPs (Source IP)
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);
    __type(value, __u32);
} csf_drop_map SEC(".maps");

// Map 2: Allowed UDP Ports
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_udp_allow_map SEC(".maps");

// Map 3: Allowed TCP Ports
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);
    __type(value, __u32);
} csf_tcp_allow_map SEC(".maps");

// Map 4: Config Flags
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u32);
} csf_conf_map SEC(".maps");

// Helper to swap addresses for ECHO (Reflect)
static inline void swap_src_dst(struct ethhdr *eth, struct iphdr *ip) {
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

    // ------------------------------------------------------
    // 1. Parse Ethernet Header
    // ------------------------------------------------------
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end) return XDP_PASS;

    // Only handle IPv4 (0x0800)
    if (eth->h_proto != bpf_htons(ETH_P_IP)) return XDP_PASS;

    // ------------------------------------------------------
    // 2. Parse IP Header
    // ------------------------------------------------------
    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end) return XDP_PASS;

    // [CRITICAL FIX]: Calculate actual IP header length. 
    // IHL is the number of 32-bit words. 
    // A standard header is 5 words (20 bytes).
    __u32 ip_len = ip->ihl * 4;
    
    // Sanity check: IP header must be at least 20 bytes
    if (ip_len < 20) return XDP_DROP;

    // ------------------------------------------------------
    // 3. Check Dynamic Blocklist (Source IP)
    // ------------------------------------------------------
    __u32 src_ip = ip->saddr;
    __u32 *action = bpf_map_lookup_elem(&csf_drop_map, &src_ip);

    if (action) {
        if (*action == 1) { // ECHO / REFLECT
            swap_src_dst(eth, ip);
            return XDP_TX;
        }
        return XDP_DROP; // Default DROP
    }

    // ------------------------------------------------------
    // 4. Strict UDP Whitelist
    // ------------------------------------------------------
    if (ip->protocol == IPPROTO_UDP) {
        __u32 key_udp_strict = 0;
        __u32 *udp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_udp_strict);

        if (udp_strict_flag && *udp_strict_flag == 1) {
            // [FIX]: Use calculated ip_len, not sizeof(*ip)
            struct udphdr *udp = (void *)ip + ip_len;
            
            if ((void *)(udp + 1) > data_end) return XDP_PASS; // Malformed

            __u32 dest_port = bpf_ntohs(udp->dest);
            __u32 *allowed = bpf_map_lookup_elem(&csf_udp_allow_map, &dest_port);

            if (!allowed) return XDP_DROP;
        }
    }

    // ------------------------------------------------------
    // 5. Strict TCP Whitelist
    // ------------------------------------------------------
    if (ip->protocol == IPPROTO_TCP) {
        __u32 key_tcp_strict = 1;
        __u32 *tcp_strict_flag = bpf_map_lookup_elem(&csf_conf_map, &key_tcp_strict);

        if (tcp_strict_flag && *tcp_strict_flag == 1) {
            // [FIX]: Use calculated ip_len, not sizeof(*ip)
            struct tcphdr *tcp = (void *)ip + ip_len;
            
            if ((void *)(tcp + 1) > data_end) return XDP_PASS; // Malformed

            __u32 dest_port = bpf_ntohs(tcp->dest);
            __u32 *allowed = bpf_map_lookup_elem(&csf_tcp_allow_map, &dest_port);

            if (!allowed) return XDP_DROP;
        }
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";