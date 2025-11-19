// 
// CSF XDP Drop Actions
// Implements high-performance packet handling for common firewall targets.
//
// Targets:
//   DROP   -> XDP_DROP (Silent, immediate drop)
//   ECHO   -> XDP_TX   (Reflect packet back to sender)
//   REJECT -> XDP_TX   (Reflects, effectively rejecting without RST generation complexity)
//

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/udp.h>
#include <linux/tcp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Define a map to store blocked IPs and their action code
// Key: IP Address (u32), Value: Action Code (u32)
// Action Codes:
//   0 = XDP_DROP (DROP, TARPIT, DELUDE - simplify to drop for speed)
//   1 = XDP_TX   (ECHO, REJECT - bounce back)
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);
    __type(value, __u32);
} csf_drop_map SEC(".maps");

// Helper to swap MAC addresses for XDP_TX (Echo)
static inline void swap_src_dst_mac(void *data) {
    struct ethhdr *eth = data;
    unsigned char tmp[ETH_ALEN];
    __builtin_memcpy(tmp, eth->h_source, ETH_ALEN);
    __builtin_memcpy(eth->h_source, eth->h_dest, ETH_ALEN);
    __builtin_memcpy(eth->h_dest, tmp, ETH_ALEN);
}

// Helper to swap IP addresses for XDP_TX
static inline void swap_src_dst_ipv4(struct iphdr *ip) {
    __u32 tmp = ip->saddr;
    ip->saddr = ip->daddr;
    ip->daddr = tmp;
}

SEC("xdp")
int csf_firewall_prog(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data;
    struct iphdr *ip;

    // sanity check
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    // Only handle IPv4 for now
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    // Lookup Source IP in our map
    __u32 src_ip = ip->saddr;
    __u32 *action = bpf_map_lookup_elem(&csf_drop_map, &src_ip);

    if (action) {
        // Found in blocklist! Check action code.
        
        // Action 0: DROP (Standard Drop, Tarpit, etc.)
        if (*action == 0) {
            return XDP_DROP;
        }

        // Action 1: ECHO / REJECT (Reflect packet)
        if (*action == 1) {
            // We need to modify the packet to send it back
            swap_src_dst_mac(data);
            swap_src_dst_ipv4(ip);
            
            // Recalculate checksum (simplified, assuming HW offload will fix or irrelevant for flood)
            // Note: For TCP/UDP ports, we'd swap them too, but purely swapping IPs/MACs 
            // is often enough to "echo" the traffic load back.
            
            return XDP_TX; 
        }
        
        // Default fallback if unknown action code
        return XDP_DROP; 
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";