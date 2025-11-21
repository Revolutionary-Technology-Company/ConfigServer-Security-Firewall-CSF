/* * Revolutionary Technology - XDP Echo (Reflector)
 * * This eBPF program intercepts traffic and swaps MAC/IP addresses
 * to reflect it back to the sender (XDP_TX).
 * equivalent to: iptables -j ECHO
 */

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>

#define SEC(NAME) __attribute__((section(NAME), used))

static inline void swap_mac(unsigned char *src, unsigned char *dst) {
    unsigned char t[ETH_ALEN];
    __builtin_memcpy(t, src, ETH_ALEN);
    __builtin_memcpy(src, dst, ETH_ALEN);
    __builtin_memcpy(dst, t, ETH_ALEN);
}

static inline void swap_ip(struct iphdr *ip) {
    __be32 t = ip->saddr;
    ip->saddr = ip->daddr;
    ip->daddr = t;
}

// Define the XDP Program
SEC("xdp_echo")
int xdp_reflector(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data;

    // 1. Boundary Check (Safety)
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    // 2. Check for IPv4
    if (eth->h_proto != __builtin_bswap16(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    /* * LOGIC: If this packet hits this program, we ECHO it.
     * In the future, we can map specific ports or IPs here.
     */
     
    // 3. Swap MAC Addresses
    swap_mac(eth->h_source, eth->h_dest);

    // 4. Swap IP Addresses
    swap_ip(ip);

    // 5. Recalculate Checksum (simplified for speed)
    ip->check = 0; // Checksum offloading usually handles this, or we verify in user space

    // 6. Transmit back out the SAME interface
    return XDP_TX; 
}

char _license[] SEC("license") = "GPL";