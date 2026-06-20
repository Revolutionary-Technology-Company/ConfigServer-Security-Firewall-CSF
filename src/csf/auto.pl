#!/usr/bin/perl
# ==============================================================================
# @app          ConfigServer Security & Firewall (CSF) - Enterprise Edition
# @website      https://configserver.shop
# @copyright    Copyright (C) 2025-2026 Revolutionary Technology
# @description  Omni-Auto Updater & Cron Orchestrator (Modernized)
# ==============================================================================

use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;
use ConfigServer::URLGet;
umask(0177);

our (%config, %configsetting, $vps, $oldversion);
$oldversion = $ARGV[0] || "";

# 1. READ CURRENT VERSION
open (VERSION, "<","/etc/csf/version.txt") or die "Unable to open version.txt: $!";
flock (VERSION, LOCK_SH);
my $version = <VERSION>;
close (VERSION);
chomp $version;
$version =~ s/\W/_/g;

# 2. BACKUP CONFIGURATION PRE-UPGRADE
if (-e "/etc/csf/csf.conf") {
    system("/bin/cp", "-avf", "/etc/csf/csf.conf", "/var/lib/csf/backup/".time."_pre_v${version}_upgrade");
}

&loadcsfconfig;

# 3. ENVIRONMENT DETECTION (VPS / OS)
if (-e "/proc/vz/veinfo") {
    $vps = 1;
} else {
    open (my $IN, "<","/proc/self/status"); 
    if ($IN) {
        flock ($IN, LOCK_SH);
        while (my $line = <$IN>) {
            chomp $line;
            if ($line =~ /^envID:\s*(\d+)\s*$/ && $1 > 0) {
                $vps = 1;
                last;
            }
        }
        close ($IN);
    }
}

if ($config{GENERIC}) {
    exec "/usr/local/csf/bin/auto.generic.pl";
    exit;
}

# 4. TEMPLATE SANITY CHECKS
foreach my $alertfile ("sshalert.txt","sualert.txt","sudoalert.txt","webminalert.txt","cpanelalert.txt") {
    if (-e "/usr/local/csf/tpl/".$alertfile) {
        sysopen (my $IN, "/usr/local/csf/tpl/".$alertfile, O_RDWR | O_CREAT);
        flock ($IN, LOCK_EX);
        my @data = <$IN>;
        chomp @data;
        my $hit = 0;
        foreach my $line (@data) {
            if ($line =~ /\[text\]/) { $hit = 1; last; }
        }
        unless ($hit) {
            print $IN "\nLog line:\n\n[text]\n";
        }
        close ($IN);
    }
}

# ===============================================================================
# REVOLUTIONARY TECHNOLOGY: MODERN UPDATE ENGINE
# ===============================================================================
my $urlget = ConfigServer::URLGet->new();

sub check_and_update {
    my $force = 0;
    if (grep { $_ eq '-uf' } @ARGV) {
        $force = 1;
    }

    my $url = "https://$config{DOWNLOADSERVER}/csf/version.txt";
    $url = "http://$config{DOWNLOADSERVER}/csf/version.txt" if ($config{URLGET} == 1);
    
    my ($status, $actv) = $urlget->urlget($url);
    if ($status) {
        print "[-] RT Update Engine Error: Unable to reach download server.\n";
        return;
    }
    
    $actv =~ s/^\s+|\s+$//g;
    my ($actv_num)  = $actv =~ /^([\d.]+)/;
    my ($curr_num)  = $version =~ /^([\d.]+)/;
    
    if ($actv_num eq "" && !$force) {
        print "[-] Unable to parse remote version.\n";
        return;
    }

    my $newer = 0;
    my @a = split /\./, $curr_num // '0';
    my @b = split /\./, $actv_num  // '0';
    
    for (my $i = 0; $i < @a || $i < @b; $i++) {
        my $c = $a[$i] // 0;
        my $n = $b[$i] // 0;
        if ($n > $c) { $newer = 1; last; }
        if ($n < $c) { $newer = 0; last; }
    }

    if ($newer || $force) {
        local $| = 1;
        print "[*] Upgrading CSF from v$version to v$actv...\n" unless $force;
        
        unlink("/usr/src/csf.tgz") if (-e "/usr/src/csf.tgz");
        
        my $dl_url = "https://$config{DOWNLOADSERVER}/csf.tgz";
        $dl_url = "http://$config{DOWNLOADSERVER}/csf.tgz" if ($config{URLGET} == 1);
        
        print "[*] Downloading update payload from: $dl_url\n";
        my ($dl_status, $dl_text) = $urlget->urlget($dl_url, "/usr/src/csf.tgz");
        
        if (! -z "/usr/src/csf.tgz") {
            print "[*] Unpacking and applying update...\n";
            system("cd /usr/src ; tar -xzf csf.tgz ; cd csf ; sh install.sh");
            system("rm -Rfv /usr/src/csf*");
            
            print "[*] Restarting Daemon & Firewall...\n";
            system("/usr/sbin/csf -r");
            
            # Trigger Custom RT Hooks Post-Update
            &trigger_rt_engines;
            
            print "[+] Update complete. Welcome to v$actv\n";
        } else {
            print "[-] Download failed. Archive is empty.\n";
        }
    } else {
        print "[+] CSF is up to date (v$version).\n";
        
        # Still run nightly routine if running via cron
        &trigger_rt_engines; 
    }
}

# ===============================================================================
# REVOLUTIONARY TECHNOLOGY: ENGINE ORCHESTRATION HOOKS
# ===============================================================================
sub trigger_rt_engines {
    print "[*] Checking RT Enterprise Extensions...\n";
    
    # 1. Trigger the Python Numba/CUDA Engine if installed
    if (-x "/etc/csf/plugins/rt_enterprise_engine.py") {
        print "  -> Executing RT Python Multicore Orchestrator...\n";
        system("/etc/csf/plugins/rt_enterprise_engine.py poll-threat-intel >/dev/null 2>&1 &");
        system("/etc/csf/plugins/rt_enterprise_engine.py sync-suricata >/dev/null 2>&1 &");
    }
    
    # 2. Re-compile XDP Modules if kernel updated
    if (-x "/etc/csf/compile_xdp.sh") {
        print "  -> Verifying XDP hardware offloads...\n";
        system("cd /etc/csf && ./compile_xdp.sh >/dev/null 2>&1 &");
    }
    
    # 3. Legacy RT Scripts Fallback
    if (-x "/etc/csf/rt-csf-update.sh") {
        system("/etc/csf/rt-csf-update.sh >/dev/null 2>&1 &");
    }
}

# ===============================================================================
# CONFIGURATION PARSER
# ===============================================================================
sub loadcsfconfig {
    open (my $IN, "<", "/etc/csf/csf.conf") or return;
    flock ($IN, LOCK_SH);
    while (my $line = <$IN>) {
        chomp $line;
        next if $line =~ /^\#/;
        next if $line !~ /=/;
        my ($name, $value) = split(/=/, $line, 2);
        $name =~ s/\s//g;
        $value =~ s/\"//g;
        $config{$name} = $value;
        $configsetting{$name} = 1;
    }
    close ($IN);
}

# Execution Entry Point
&check_and_update;
exit 0;
