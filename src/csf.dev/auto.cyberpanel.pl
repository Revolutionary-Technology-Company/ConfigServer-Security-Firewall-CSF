#!/usr/bin/perl
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.shop
# ... (Header matches previous)

# ... (Existing checks) ...

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

# ... (Rest of iptables checks) ...

if ($config{TESTING}) {
    # [REVOLUTIONARY TECH UPDATE]
    # Added fallback to 'ss' because 'netstat' is deprecated/missing on modern minimal distros
	my @netstat = `netstat -lpn 2>/dev/null`;
    if (!@netstat) {
        @netstat = `ss -lpn`;
    }
	chomp @netstat;
    # ... (Rest of the processing loop)