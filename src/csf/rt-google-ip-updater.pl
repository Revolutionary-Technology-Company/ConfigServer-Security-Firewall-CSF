#!/usr/bin/perl
# #
#   @script             Revolutionary Technology Google IP Updater
#   @description        Fetches official Google Crawler/Bot IPs (IPv4/IPv6)
#                       and updates csf.allow while preserving custom rules.
#   @frequency          Weekly (via cron)
# #

use strict;
use warnings;

my $allow_file = "/etc/csf/csf.allow";
my $csf_cmd    = "/usr/sbin/csf";
my @urls       = (
    "https://developers.google.com/static/search/apis/ipranges/googlebot.json",
    "https://developers.google.com/static/search/apis/ipranges/special-crawlers.json",
    "https://developers.google.com/static/search/apis/ipranges/user-triggered-fetchers.json",
    "https://developers.google.com/static/search/apis/ipranges/user-triggered-fetchers-google.json"
);

# The ASNs you requested to allow explicitly
my @asns = (
    "AS15169", "AS40873", "AS395973", "AS36492", "AS36040",
    "AS43515", "AS36561", "AS19527",  "AS139070", "AS396982"
);

# --- 1. Fetch IPs from Google ---
print "Fetching Google IP ranges...\n";
my %ips;
foreach my $url (@urls) {
    # Try wget first, fall back to curl
    my $cmd = "wget -qO- \"$url\" --timeout=10 --tries=2";
    my $json = `$cmd`;
    
    if ($? != 0 || !$json) {
        $cmd = "curl -s \"$url\" --connect-timeout 10 --retry 2";
        $json = `$cmd`;
    }

    if ($json) {
        # Simple regex extraction to avoid dependency hell with JSON modules
        while ($json =~ /"ipv4Prefix":\s*"([^"]+)"/g) { $ips{$1} = 1; }
        while ($json =~ /"ipv6Prefix":\s*"([^"]+)"/g) { $ips{$1} = 1; }
    } else {
        warn "Warning: Failed to fetch $url\n";
    }
}

if (scalar keys %ips < 5) {
    die "Error: Too few IPs fetched. Aborting update to prevent lockout.\n";
}

# --- 2. Read existing csf.allow ---
open(my $fh, "<", $allow_file) or die "Cannot read $allow_file: $!";
my @lines = <$fh>;
close($fh);

# --- 3. Rebuild file content ---
my @new_lines;
my $in_block = 0;

foreach my $line (@lines) {
    if ($line =~ /^# BEGIN Revolutionary Technology Google IPs/) {
        $in_block = 1;
        next;
    }
    if ($line =~ /^# END Revolutionary Technology Google IPs/) {
        $in_block = 0;
        next;
    }
    push @new_lines, $line unless $in_block;
}

# Remove trailing newlines to make clean append
while (@new_lines && $new_lines[-1] =~ /^\s*$/) { pop @new_lines; }
push @new_lines, "\n";

# --- 4. Append new Google Block ---
push @new_lines, "# BEGIN Revolutionary Technology Google IPs\n";
push @new_lines, "# Updated: " . scalar(localtime) . "\n";

# Add ASNs
foreach my $asn (@asns) {
    # Format for CSF: do:ASN:NUMBER
    my $clean_asn = $asn;
    $clean_asn =~ s/^AS//i; 
    push @new_lines, "do:ASN:$clean_asn # Google ASN $asn\n";
}

# Add IPs
foreach my $ip (sort keys %ips) {
    push @new_lines, "$ip # Google Bot/Crawler\n";
}

push @new_lines, "# END Revolutionary Technology Google IPs\n";

# --- 5. Write and Restart ---
open($fh, ">", $allow_file) or die "Cannot write $allow_file: $!";
print $fh @new_lines;
close($fh);

print "Updated csf.allow with " . scalar(keys %ips) . " Google IPs and " . scalar(@asns) . " ASNs.\n";

# Reload CSF/LFD without full restart (fast reload)
system("$csf_cmd -ra >/dev/null 2>&1");