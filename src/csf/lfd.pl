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
#                       Copyright (C) 2025-2026 Revolutionary Technology https://revolutionarytechnology.net
#   @license            GPLv3
#   @updated            10.13.2025
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
# #
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen, RequireLocalizedPunctuationVars)
# start main
use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use IO::Handle;
# use URI::Escape;
use IPC::Open3;
use Net::CIDR::Lite;
use POSIX qw(:sys_wait_h sysconf strftime setsid);
use Socket;
use ConfigServer::Config;
use ConfigServer::Slurp qw(slurp);
use ConfigServer::CheckIP qw(checkip cccheckip);
use ConfigServer::URLGet;
use ConfigServer::GetIPs qw(getips);
use ConfigServer::Service;
use ConfigServer::AbuseIP qw(abuseip);
use ConfigServer::GetEthDev;
use ConfigServer::Sendmail;
use ConfigServer::Logger qw(logfile);
use ConfigServer::KillSSH;
use ConfigServer::LookUpIP qw(iplookup);

# ... [Rest of the file remains technically identical, just ensure line 223 matches below] ...

# #
#	Define › App vars
# #

my $app_github_url = "https://github.com/orgs/Revolutionary-Technology-Company/";