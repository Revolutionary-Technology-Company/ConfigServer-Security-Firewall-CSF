# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            03.05.2026
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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::Packages;

use strict;
use warnings;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use Carp;
use ConfigServer::Config;

# #
#	Packages.pm › Declare › Version
# #

our $VERSION 	= 15.10;

# #
#	Packages.pm › Declare › Config
# #

my $config_obj	= ConfigServer::Config->loadconfig();
my %config 		= $config_obj->config();

# #
#	Packages.pm › Which
#   
#   Attempt to locate package binary on a system, similar to the Unix `which` command.
#   
#   If an absolute or relative path is provided (contains '/'), it checks if
#   that file exists and is executable.
#   
#   Alternatively, it searches the dirs listed in $ENV{PATH}. On Linux, PATH
#   entries are separated by ':'; we also accept ';'.
#   
#   In CSF (or other daemons), $PATH may be empty or stripped for
#   security reasons. If so, we specify a set of common system dirs which are
#   used as a fallback.
#   
#   Returns the full path to the executable if found, otherwise undef.
#   
#   @usage      my $found = _which( '/usr/bin/apt' )
#   @scope      local
#   @param      bin         str                     path to binary
#   @return                 str                     full path to binary if found, otherwise undef
# #

sub _which
{
    my ( $bin ) = @_;
    return undef if !defined $bin || $bin eq "";

    # #
    #   Absolute/relative path provided
    # #

    if ( $bin =~ m{/} )
    {
        return -x $bin ? $bin : undef;
    }

    my @dirs;
    my $path    = $ENV{PATH} // "";

    if ( $path ne "" )
    {
        # #
        #   Env variable Linux typically uses ':', but be tolerant of ';'
        # #
    
        @dirs = grep { defined && $_ ne "" } split( /[:;]/, $path );
    }

    # #
    #   Fallback for daemon/web contexts with a stripped PATH
    # #

    push @dirs, qw(
        /usr/local/sbin
        /usr/local/bin
        /usr/sbin
        /usr/bin
        /sbin
        /bin
    ) if !@dirs;

    foreach my $dir ( @dirs )
    {
        my $full = "$dir/$bin";
        return $full if -x $full;
    }

    return undef;
}

# #
#   Packages.pm › Get Command
#   
#   Determines which package manager is available on the system and builds
#   a full install command for a given package.
#   
#   First checks using $PATH for candidate binaries. However, when
#   running CSF (or other daemons), $PATH is often empty or
#   stripped down for security reasons. Secondary, we check a list of
#   known locations for each package manager (defined in 'detect =>').
#   
#   Supports hash key `all`, which sets the same package name for all package
#   managers.
#   
#   If package name is different for each package manager, must specify each
#   key for the package manager's package name individually.
#   
#   @usage      my $cmd = getcommand( all => "openssl" );
#               my $cmd = getcommand( apt => "openssl", pacman => "openssl" );
#   @scope      public
#   @param      bin         hash                    keys:   package manager
#                                                   value:  package name to install
#   @return                 str                     full path to binary if found, otherwise undef
# #

sub getcommand
{
    my %pkg_for 	= @_;

    # #
    #   foreach my $key ( keys %pkg_for )
    #   {
    #       print "$key => $pkg_for{$key}\n";
    #   }
    # #

    my $all 		= delete $pkg_for{all};

    # #
    #   Package Managers
    #   
    #   List of all the package managers we support.
    # #

    my @mgrs = (
        {
            name    => "apt",
            detect  => [ "/usr/bin/apt", "/usr/bin/apt-get", "apt", "apt-get" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
        {
            name    => "dnf",
            detect  => [ "/usr/bin/dnf", "/bin/dnf", "dnf" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
        {
            name    => "yum",
            detect  => [ "/usr/bin/yum", "/bin/yum", "yum" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
        {
            name    => "pacman",
            detect  => [ "/usr/bin/pacman", "/bin/pacman", "pacman" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd -S $pkg"; },
        },
        {
            name    => "apk",
            detect  => [ "/sbin/apk", "/usr/sbin/apk", "/usr/bin/apk", "apk" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd add $pkg"; },
        },
        {
            name    => "zypper",
            detect  => [ "/usr/bin/zypper", "/bin/zypper", "zypper" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
        {
            name    => "proteus",
            detect  => [ "/usr/bin/proteus", "/bin/proteus", "proteus" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
        {
            name    => "csfpkg",
            detect  => [ "/usr/bin/csfpkg", "/bin/csfpkg", "csfpkg" ],
            build   => sub { my ( $cmd, $pkg ) = @_; return "$cmd install $pkg"; },
        },
    );

    # #
    #   Iterate over package managers; find command path / command
    # #

    foreach my $mgr ( @mgrs )
    {
        my $pkg = defined( $all ) ? $all : $pkg_for{ $mgr->{name} };
        next if !defined $pkg || $pkg eq "";

        my $cmd;
        my $cmd_path;
        foreach my $candidate ( @{ $mgr->{detect} } )
        {
            if ( my $found = _which( $candidate ) )
            {
                # #
                #   Use the manager (apt vs apt-get) that was found
                # #
    
                $cmd_path   = $found;           # e.g. /usr/bin/apt
                $cmd        = $cmd_path;        # start with full path
                $cmd        =~ s{.*/}{};        # becomes: apt (or apt-get, dnf, etc.)

                last;
            }
        }

        next if !$cmd;

        my $install = $mgr->{build}->( $cmd, $pkg );
        return wantarray ? ( $mgr->{name}, $pkg, $install ) : $install;
    }

    return wantarray ? ( "Unknown", "Unknown", "Unknown" ) : "Unknown";
}