#!/usr/bin/perl

# 
# Revolutionary Technology - Google IP Updater
# Copyright (C) 2025 Revolutionary Technology
#
# This script fetches Google Bot & Service IPs from their official
# JSON endpoints and adds them to /etc/csf/csf.allow.
# It uses markers to replace the old block, preventing file bloat.
#

use strict;
use warnings;
use LWP::Simple;
use JSON::MaybeXS;
use Fcntl qw(:flock);

my $csf_allow    = "/etc/csf/csf.allow";
my $temp_allow   = "/etc/csf/csf.allow.tmp.$$"; # Use process ID for temp file
my $csf_bin      = "/usr/sbin/csf";

my @google_urls = (
    "https://developers.google.com/search/apis/ipranges/googlebot.json",
    "https://www.gstatic.com/ipranges/goog.json"
);

my $marker_begin = "# BEGIN Revolutionary Technology Google IPs";
my $marker_end   = "# END Revolutionary Technology Google IPs";

my %ip_prefixes;
my $json = JSON::MaybeXS->new(utf8 => 1);

# --- 1. Fetch and Parse IPs ---
foreach my $url (@google_urls) {
    my $content = get($url);
    unless ($content) {
        print "Warning: Could not fetch $url. Skipping.\n";
        next;
    }
    
    my $data;
    eval { $data = $json->decode($content); };
    if ($@) {
        print "Warning: Could not parse JSON from $url. Skipping.\n";
        next;
    }

    if (exists $data->{'prefixes'} && ref $data->{'prefixes'} eq 'ARRAY') {
        foreach my $prefix (@{ $data->{'prefixes'} }) {
            my $comment = ($url =~ /googlebot/) ? "Google Bot" : "Google Service";
            
            if (exists $prefix->{'ipv4Prefix'}) {
                $ip_prefixes{ $prefix->{'ipv4Prefix'} } = $comment;
            }
            if (exists $prefix->{'ipv6Prefix'}) {
                $ip_prefixes{ $prefix->{'ipv6Prefix'} } = $comment;
            }
        }
    }
}

unless (keys %ip_prefixes) {
    die "Error: No IP prefixes were successfully fetched from any source. Aborting update to $csf_allow.";
}

# --- 2. Safely Update csf.allow ---
unless (open(my $read_fh, "<", $csf_allow)) {
    die "Error: Cannot open $csf_allow for reading: $!";
}

unless (open(my $write_fh, ">", $temp_allow)) {
    close $read_fh;
    die "Error: Cannot open $temp_allow for writing: $!";
}

# Lock the temp file
flock($write_fh, LOCK_EX) or die "Error: Cannot lock $temp_allow: $!";

my $in_google_block = 0;

while (my $line = <$read_fh>) {
    if ($line =~ /^\Q$marker_begin\E/) {
        $in_google_block = 1;
        next; # Skip this line, we'll write a new one
    }
    if ($line =~ /^\Q$marker_end\E/) {
        $in_google_block = 0;
        next; # Skip this line, we'll write a new one
    }
    
    print $write_fh $line unless $in_google_block;
}

close $read_fh;

# --- 3. Write New Block ---
# (This will append to the file if the markers weren't found, which is fine)
print $write_fh "\n$marker_begin\n";
foreach my $ip (sort keys %ip_prefixes) {
    print $write_fh "$ip # $ip_prefixes{$ip}\n";
}
print $write_fh "$marker_end\n";

close $write_fh; # This releases the lock

# --- 4. Atomic Replace and Reload ---
if (rename($temp_allow, $csf_allow)) {
    print "Successfully updated Google IPs in $csf_allow.\n";
    
    if (-x $csf_bin) {
        system("$csf_bin -r > /dev/null 2>&1");
        print "CSF firewall reloaded.\n";
    }
} else {
    print "Error: Failed to move $temp_allow to $csf_allow: $!\n";
    unlink $temp_allow; # Clean up temp file
}

exit 0;