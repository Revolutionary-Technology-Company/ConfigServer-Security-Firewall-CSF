#!/usr/bin/perl
# Revolutionary Technology - ModSec3 to LFD Converter Daemon
# Provides strict backwards compatibility for CSF's Login Failure Daemon
use strict;
use warnings;
use JSON::Tiny qw(decode_json); # Assuming JSON::Tiny is included in csf/JSON/
use File::Tail;

my $modsec3_log = "/var/log/apache2/modsec_audit.log";
my $legacy_out  = "/var/log/apache2/modsec_legacy_lfd.log";

# Open output stream for LFD to read
open(my $out_fh, ">>", $legacy_out) or die "Cannot open $legacy_out: $!";
$out_fh->autoflush(1);

my $file = File::Tail->new(name => $modsec3_log, maxinterval => 1, adjustafter => 7);

print "[RT-Engine] Translating ModSecurity 3 JSON logs for LFD compatibility...\n";

while (defined(my $line = $file->read)) {
    if ($line =~ /^{.*}$/) { # Basic JSON sanity check
        eval {
            my $data = decode_json($line);
            
            # Extract critical threat vectors
            my $client_ip = $data->{transaction}->{client_ip};
            my $messages  = $data->{transaction}->{messages};
            
            if ($client_ip && $messages && scalar(@$messages) > 0) {
                foreach my $msg (@$messages) {
                    my $rule_id = $msg->{details}->{ruleId} || "Unknown";
                    my $message = $msg->{message} || "ModSecurity 3 Violation";
                    
                    # Output a reconstructed string that natively matches CSF's built-in LF_MODSEC parsers
                    # Matches: [Mon Jan 01 00:00:00.0000 2026] [:error] [pid 12345] [client 192.168.1.1:5000] [ModSecurity] Access denied...
                    my $timestamp = localtime();
                    my $flat_log = "[$timestamp] [:error] [pid 00000] [client $client_ip:1234] [ModSecurity] Access denied with code 403. Pattern match. [id \"$rule_id\"] [msg \"$message\"]\n";
                    
                    print $out_fh $flat_log;
                }
            }
        };
    }
}
