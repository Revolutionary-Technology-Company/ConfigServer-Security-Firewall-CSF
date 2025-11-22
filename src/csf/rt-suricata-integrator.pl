#!/usr/bin/perl
# #
#   @script             Revolutionary Technology Suricata-CSF Bridge
#   @description        Real-time log monitor that bans Suricata alerts in CSF.
#   @copyright          Copyright (C) 2025 Revolutionary Technology
# #

use strict;
use warnings;
use File::Tail;
use IPC::Open3;

# --- Configuration ---
my $log_file = "/var/log/suricata/fast.log";
my $csf_cmd  = "/usr/sbin/csf";
# ---------------------

# Ensure log exists
if (! -f $log_file) {
    system("touch $log_file");
}

print "Starting Suricata-CSF Bridge...\n";
print "Watching: $log_file\n";

my $file = File::Tail->new(name => $log_file, maxinterval => 2, adjustafter => 7);

while (defined(my $line = $file->read)) {
    # Parse Suricata fast.log format:
    # [**] [1:2000001:1] ET MALWARE ... [**] ... {TCP} 192.168.1.50:12345 -> ...
    
    if ($line =~ /\[\*\*\]\s+\[(\d+:\d+:\d+)\]\s+(.*)\s+\[\*\*\]\s+.*\{(\w+)\}\s+(\d+\.\d+\.\d+\.\d+)/) {
        my $sid = $1;
        my $msg = $2;
        my $proto = $3;
        my $src_ip = $4;

        # Ignore local IPs to prevent self-lockout
        if ($src_ip =~ /^127\.|^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./) {
            next;
        }

        # Ban the IP in CSF
        # -d = Deny, -comment = Reason
        my $reason = "Suricata Alert: $msg (SID: $sid)";
        system("$csf_cmd -d $src_ip \"$reason\" >/dev/null 2>&1");
        
        # Log to stdout (visible in systemctl status)
        print "[Blocked] $src_ip - $msg\n";
    }
}