// csf_xdp_drop.c
// ConfigServer by Revolutionary Technology - XDP Hardware Offloading Engine
// Compile: clang -O2 -target bpf -c csf_xdp_drop.c -o csf_xdp_drop.o

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define ACTION_DROP   0
#define ACTION_TARPIT 1
#define ACTION_ECHO   2
#define ACTION_CHAOS  3

// --- BPF Maps ---

// Map for blocked IPs and their assigned Action
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);   // IPv4 Address
    __type(value, __u8);  // Action ID
} blocked_ips SEC(".maps");

// Map for Whitelisted TCP Ports (RT_TCP_XDP_STRICT)
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 65535);
    __type(key, __u16);
    __type(value, __u8);
} tcp_whitelist SEC(".maps");

// Map for Whitelisted UDP Ports (RT_UDP_XDP_STRICT)
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 65535);
    __type(key, __u16);
    __type(value, __u8);
} udp_whitelist SEC(".maps");

// Config map to toggle STRICT modes (0 = off, 1 = on)
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);   // 0 = TCP_STRICT, 1 = UDP_STRICT
    __type(value, __u8);
} strict_modes SEC(".maps");

// --- Helper Functions ---

// Swaps MAC addresses for XDP_TX reflection
static inline void swap_mac(struct ethhdr *eth) {
    __u8 tmp[ETH_ALEN];
    __builtin_memcpy(tmp, eth->h_source, ETH_ALEN);
    __builtin_memcpy(eth->h_source, eth->h_dest, ETH_ALEN);
    __builtin_memcpy(eth->h_dest, tmp, ETH_ALEN);
}

// Swaps IP addresses for XDP_TX reflection
static inline void swap_ip(struct iphdr *iph) {
    __u32 tmp = iph->saddr;
    iph->saddr = iph->daddr;
    iph->daddr = tmp;
}

SEC("xdp_shield")
int rt_xdp_firewall(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS; // Only process IPv4 for now

    struct iphdr *iph = (void *)(eth + 1);
    if ((void *)(iph + 1) > data_end)
        return XDP_PASS;

    __u32 src_ip = iph->saddr;
    
    // 1. Check if IP is in the Blocklist Map
    __u8 *action = bpf_map_lookup_elem(&blocked_ips, &src_ip);
    if (action) {
        if (*action == ACTION_DROP) {
            return XDP_DROP;
        } 
        else if (*action == ACTION_ECHO) {
            // ECHO: Reflect the packet exactly as it arrived
            swap_mac(eth);
            swap_ip(iph);
            // Note: Checksums remain valid because total bit value hasn't changed (just swapped)
            return XDP_TX;
        }
        else if (*action == ACTION_CHAOS) {
            // CHAOS: Randomize response to confuse scanners
            __u32 rand = bpf_get_prandom_u32() % 100;
            if (rand < 50) return XDP_DROP; // 50% chance silent drop
            
            swap_mac(eth);
            swap_ip(iph);
            return XDP_TX; // 50% chance echo
        }
        else if (*action == ACTION_TARPIT) {
            // TARPIT (TCP Only): If SYN, reply with SYN-ACK and Window=0
            if (iph->protocol == IPPROTO_TCP) {
                struct tcphdr *tcph = (void *)iph + (iph->ihl * 4);
                if ((void *)(tcph + 1) > data_end) return XDP_DROP;

                if (tcph->syn && !tcph->ack) {
                    swap_mac(eth);
                    swap_ip(iph);
                    
                    __u16 tmp_port = tcph->source;
                    tcph->source = tcph->dest;
                    tcph->dest = tmp_port;
                    
                    tcph->ack = 1;
                    tcph->ack_seq = bpf_htonl(bpf_ntohl(tcph->seq) + 1);
                    tcph->seq = bpf_get_prandom_u32(); // Random seq
                    tcph->window = 0; // The TARPIT magic: Window Size 0 holds connection open
                    
                    // (In a full production build, incremental BPF checksum recalculation goes here)
                    
                    return XDP_TX;
                }
            }
            return XDP_DROP;
        }
    }

    // 2. Zero-Trust Strict Mode Processing (TCP/UDP)
    __u32 tcp_idx = 0, udp_idx = 1;
    __u8 *tcp_strict = bpf_map_lookup_elem(&strict_modes, &tcp_idx);
    __u8 *udp_strict = bpf_map_lookup_elem(&strict_modes, &udp_idx);

    if (iph->protocol == IPPROTO_TCP) {
        struct tcphdr *tcph = (void *)iph + (iph->ihl * 4);
        if ((void *)(tcph + 1) > data_end) return XDP_PASS;
        
        __u16 dest_port = bpf_ntohs(tcph->dest);
        
        if (tcp_strict && *tcp_strict == 1) {
            __u8 *allowed = bpf_map_lookup_elem(&tcp_whitelist, &dest_port);
            if (!allowed) return XDP_DROP; // RT_TCP_XDP_STRICT Enforcement
        }
    } 
    else if (iph->protocol == IPPROTO_UDP) {
        struct udphdr *udph = (void *)iph + (iph->ihl * 4);
        if ((void *)(udph + 1) > data_end) return XDP_PASS;
        
        __u16 dest_port = bpf_ntohs(udph->dest);
        
        if (udp_strict && *udp_strict == 1) {
            __u8 *allowed = bpf_map_lookup_elem(&udp_whitelist, &dest_port);
            if (!allowed) return XDP_DROP; // RT_UDP_XDP_STRICT Enforcement
        }
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
