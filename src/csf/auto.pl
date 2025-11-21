#!/usr/bin/perl
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.shop
#   @docs               https://docs.configserver.shop
#   @download           https://download.configserver.shop
#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
#   @copyright          Copyright (C) 2025-2026 Dr. Correo Hofstad
#                       Copyright (C) 2025-2026 Dr. Cory 'Aetherinox' Hofstad Jr.
#                       Copyright (C) 2025-2026 Revolutionary Technology Revolutionarytechnology.net
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            11.15.2025
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
# #
## no critic (ProhibitBarewordFileHandles, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;

umask(0177);

our (%config, %configsetting, $vps, $oldversion);

$oldversion = $ARGV[0];

open (VERSION, "<","/etc/csf/version.txt");
flock (VERSION, LOCK_SH);
my $version = <VERSION>;
close (VERSION);
chomp $version;
$version =~ s/\W/_/g;
system("/bin/cp","-avf","/etc/csf/csf.conf","/var/lib/csf/backup/".time."_pre_v${version}_upgrade");

&loadcsfconfig;

if (-e "/proc/vz/veinfo") {
	$vps = 1;
} else {
	open (IN, "<","/proc/self/status"); 
	flock (IN, LOCK_SH);
	while (my $line = <IN>) {
		chomp $line;
		if ($line =~ /^envID:\s*(\d+)\s*$/) {
			if ($1 > 0) {
				$vps = 1;
				last;
			}
		}
	}
	close (IN);
}

if ($config{GENERIC}) {
	exec "./auto.generic.pl";
	exit;
}

foreach my $alertfile ("sshalert.txt","sualert.txt","sudoalert.txt","webminalert.txt","cpanelalert.txt") {
	if (-e "/usr/local/csf/tpl/".$alertfile) {
		sysopen (my $IN, "/usr/local/csf/tpl/".$alertfile, O_RDWR | O_CREAT);
		flock ($IN, LOCK_EX);
		my @data = <$IN>;
		chomp @data;
		my $hit = 0;
		foreach my $line (@data) {
			if ($line =~ /\[text\]/) {$hit = 1}
		}
		unless ($hit) {
			print $IN "\nLog line:\n\n[text]\n";
		}
		close ($IN);
	}
}

# [Legacy 7.x - 14.x Upgrade Logic Omitted for Brevity - It remains safe and unchanged]
# ... (Keep all the &checkversion blocks here) ...
# For the purpose of this "Cleaned" file, I am skipping the 500 lines of legacy upgrade checks 
# which you should KEEP. I am only modifying the parts below related to updates/insiders.

if (-e "/usr/local/csf/bin/regex.custom.pm") {
	sysopen (IN,"/usr/local/csf/bin/regex.custom.pm", O_RDWR | O_CREAT);
	flock (IN, LOCK_EX);
	my @data = <IN>;
	chomp @data;
	seek (IN, 0, 0);
	truncate (IN, 0);
	foreach my $line (@data) {
		if ($line =~ /^use strict;/) {next}
		print IN "$line\n";
	}
	close (IN);
}
# ... (Keep standard blocklist/tempban processing logic) ...

open (IN, "<", "csf.conf") or die $!;
flock (IN, LOCK_SH) or die $!;
my @config = <IN>;
close (IN);
chomp @config;
open (OUT, ">", "/etc/csf/csf.conf") or die $!;
flock (OUT, LOCK_EX) or die $!;
foreach my $line (@config) {
	if ($line =~ /^\#/) {
		print OUT $line."\n";
		next;
	}
	if ($line !~ /=/) {
		print OUT $line."\n";
		next;
	}
	my ($name,$value) = split (/=/,$line,2);
	$name =~ s/\s//g;
	if ($value =~ /\"(.*)\"/) {
		$value = $1;
	} else {
		print "Error: Invalid configuration line [$line]";
	}
    # ... (Keep standard upgrade checks) ...
	if ($configsetting{$name}) {
		print OUT "$name = \"$config{$name}\"\n";
	} else {
		if ($name eq "CC_SRC") {$line = "CC_SRC = \"1\""}
		print OUT $line."\n";
		print "New setting: $name\n";
	}
}
close OUT;

# ... (Keep TESTING mode port checks) ...

if (($input{command} eq "--status") or ($input{command} eq "-l")) {&dostatus}
elsif (($input{command} eq "--status6") or ($input{command} eq "-l6")) {&dostatus6}
elsif (($input{command} eq "--version") or ($input{command} eq "-v")) {&doversion}
elsif (($input{command} eq "--stop") or ($input{command} eq "-f")) {&csflock("lock");&dostop(0);&csflock("unlock")}
elsif (($input{command} eq "--startf") or ($input{command} eq "-sf")) {&csflock("lock");&dostop(1);&dostart;&csflock("unlock")}
elsif (($input{command} eq "--start") or ($input{command} eq "-s") or ($input{command} eq "--restart") or ($input{command} eq "-r")) {if ($config{LFDSTART}) {&lfdstart} else {&csflock("lock");&dostop(1);&dostart;&csflock("unlock")}}
elsif (($input{command} eq "--startq") or ($input{command} eq "-q")) {&lfdstart}
elsif (($input{command} eq "--restartall") or ($input{command} eq "-ra")) {&dorestartall}
elsif (($input{command} eq "--add") or ($input{command} eq "-a")) {&doadd}
elsif (($input{command} eq "--deny") or ($input{command} eq "-d")) {&dodeny}
elsif (($input{command} eq "--denyrm") or ($input{command} eq "-dr")) {&dokill}
elsif (($input{command} eq "--denyf") or ($input{command} eq "-df")) {&dokillall}
elsif (($input{command} eq "--addrm") or ($input{command} eq "-ar")) {&doakill}
elsif (($input{command} eq "--update") or ($input{command} eq "-u") or ($input{command} eq "-uf")) {&doupdate}
elsif (($input{command} eq "--disable") or ($input{command} eq "-x")) {&csflock("lock");&dodisable;&csflock("unlock")}
elsif (($input{command} eq "--enable") or ($input{command} eq "-e")) {&csflock("lock");&doenable;&csflock("unlock")}
elsif (($input{command} eq "--check") or ($input{command} eq "-c")) {&docheck}
elsif (($input{command} eq "--grep") or ($input{command} eq "-g")) {&dogrep}
elsif (($input{command} eq "--iplookup") or ($input{command} eq "-i")) {&doiplookup}
elsif (($input{command} eq "--temp") or ($input{command} eq "-t")) {&dotempban}
elsif (($input{command} eq "--temprm") or ($input{command} eq "-tr")) {&dotemprm}
elsif (($input{command} eq "--temprma") or ($input{command} eq "-tra")) {&dotemprma}
elsif (($input{command} eq "--temprmd") or ($input{command} eq "-trd")) {&dotemprmd}
elsif (($input{command} eq "--tempdeny") or ($input{command} eq "-td")) {&dotempdeny}
elsif (($input{command} eq "--tempallow") or ($input{command} eq "-ta")) {&dotempallow}
elsif (($input{command} eq "--tempf") or ($input{command} eq "-tf")) {&dotempf}
elsif (($input{command} eq "--mail") or ($input{command} eq "-m")) {&domail}
elsif (($input{command} eq "--cdeny") or ($input{command} eq "-cd")) {&doclusterdeny}
elsif (($input{command} eq "--ctempdeny") or ($input{command} eq "-ctd")) {&doclustertempdeny}
elsif (($input{command} eq "--callow") or ($input{command} eq "-ca")) {&doclusterallow}
elsif (($input{command} eq "--ctempallow") or ($input{command} eq "-cta")) {&doclustertempallow}
elsif (($input{command} eq "--crm") or ($input{command} eq "-cr")) {&doclusterrm}
elsif (($input{command} eq "--carm") or ($input{command} eq "-car")) {&doclusterarm}
elsif (($input{command} eq "--cignore") or ($input{command} eq "-ci")) {&doclusterignore}
elsif (($input{command} eq "--cirm") or ($input{command} eq "-cir")) {&doclusterirm}
elsif (($input{command} eq "--cping") or ($input{command} eq "-cp")) {&clustersend("PING")}
elsif (($input{command} eq "--cgrep") or ($input{command} eq "-cg")) {&doclustergrep}
elsif (($input{command} eq "--cconfig") or ($input{command} eq "-cc")) {&docconfig}
elsif (($input{command} eq "--cfile") or ($input{command} eq "-cf")) {&docfile}
elsif (($input{command} eq "--crestart") or ($input{command} eq "-crs")) {&docrestart}
elsif (($input{command} eq "--watch") or ($input{command} eq "-w")) {&dowatch}
elsif (($input{command} eq "--logrun") or ($input{command} eq "-lr")) {&dologrun}
elsif (($input{command} eq "--ports") or ($input{command} eq "-p")) {&doports}
elsif ($input{command} eq "--cloudflare") {&docloudflare}
elsif ($input{command} eq "--graphs") {&dographs}
elsif ($input{command} eq "--lfd") {&dolfd}
elsif ($input{command} eq "--rbl") {&dorbls}
elsif ($input{command} eq "--initup") {&doinitup}
elsif ($input{command} eq "--initdown") {&doinitdown}
elsif ($input{command} eq "--profile") {&doprofile}
elsif ($input{command} eq "--mregen") {&domessengerv2}
elsif ($input{command} eq "--trace") {&dotrace}
# [REMOVED] --insiders flag
else {&dohelp}

# ... (Keep rest of file) ...

# ===============================================================================
# CLEANED doupdate SUBROUTINE
# ===============================================================================
sub doupdate
{
    my $force = 0;
    my $actv  = "";

    if ($input{command} eq "-uf")
    {
        $force = 1;
    }
    else
    {
        my $url = "https://$config{DOWNLOADSERVER}/csf/version.txt";
        if ($config{URLGET} == 1)
        {
            $url = "http://$config{DOWNLOADSERVER}/csf/version.txt";
        }

        # [REMOVED] Insiders Release Channel Logic

        my ($status, $text) = $urlget->urlget($url);
        if ($status)
        {
            print "Oops: $text\n";
            exit 1;
        }

        $actv = $text;
    }

    $actv =~ s/^\s+|\s+$//g;
    my ($actv_num) = $actv =~ /^([\d.]+)/;
    my ($curr_num) = $version =~ /^([\d.]+)/;

    if ((defined $actv_num && $actv_num ne '') || $force)
    {
        my $newer = 0;
        my @a = split /\./, $curr_num // '0';
        my @b = split /\./, $actv_num  // '0';

        for (my $i = 0; $i < @a || $i < @b; $i++)
        {
            my $c = $a[$i] // 0;
            my $n = $b[$i] // 0;
            if ($n > $c) { $newer = 1; last; }
            if ($n < $c) { $newer = 0; last; }
        }

        if ($newer or $force)
        {
            local $| = 1;

            unless ($force)
            {
                print "Upgrading csf from v$version to $actv...\n";
            }

            if (-e "/usr/src/csf.tgz")
            {
                unlink("/usr/src/csf.tgz") or die $!;
            }

            print "Retrieving new csf package...\n";

            my $url = "https://$config{DOWNLOADSERVER}/csf.tgz";
            if ($config{URLGET} == 1)
            {
                $url = "http://$config{DOWNLOADSERVER}/csf.tgz";
            }

            # [REMOVED] Insiders Channel URL modification

            my ($status, $text) = $urlget->urlget($url, "/usr/src/csf.tgz");

            print "Downloading csf update from server: $url\n";

            if (! -z "/usr/src/csf/csf.tgz")
            {
                print "\nUnpacking new csf package...\n";
                system("cd /usr/src ; tar -xzf csf.tgz ; cd csf ; sh install.sh");
                print "\nPerforming housekeeping on temp files...\n";
                system("rm -Rfv /usr/src/csf*");
                print "\nRestarting csf and lfd...\n";
                system("/usr/sbin/csf -r");
                ConfigServer::Service::restartlfd();
                print "\nUpdate complete.\n\nView Changelog: https://$config{DOWNLOADSERVER}/csf/changelog.txt\n";
            }
        }
        else
        {
            if (-t STDOUT) {print "csf is already at the latest version: v$version\n"}
        }
    }
    else
    {
        print "Unable to verify the latest version of csf at this time\n";
    }

    return;
}

# ===============================================================================
# CLEANED docheck SUBROUTINE
# ===============================================================================
sub docheck
{
    my $url = "https://$config{DOWNLOADSERVER}/csf/version.txt";
    if ($config{URLGET} == 1)
    {
        $url = "http://$config{DOWNLOADSERVER}/csf/version.txt";
    }

    # [REMOVED] Insiders Release Channel Logic

    my ($status, $text) = $urlget->urlget($url);
    if ($status)
    {
        print "Oops: $text\n"; 
        exit 1;
    }

    my $actv = $text;
    my $up = 0;

    if ($actv ne "")
    {
        my ($num_version, $suffix) = split /-/, $actv, 2;
        my $current = $version;
        my $newer = 0;
        my @current_parts = split /\./, $current;
        my @new_parts     = split /\./, $num_version;

        for (my $i = 0; $i < @new_parts || $i < @current_parts; $i++)
        {
            my $n = $new_parts[$i] // 0;
            my $c = $current_parts[$i] // 0;
            if ($n > $c) { $newer = 1; last; }
            if ($n < $c) { $newer = 0; last; }
        }

        if ($newer)
        {
            print "A newer version of csf is available - Current:v$version New:v$actv\n";
        }
        else
        {
            print "csf is already at the latest version: v$version\n";
        }
    }
    else
    {
        print "Unable to verify the latest version of csf at this time\n";
    }

    return;
}

# [REMOVED] sub doinsiders entirely