package Cpanel::Config::ConfigObj::Driver::ConfigServercsf::META;

use strict;
use warnings;

# Update version to match your main script
our $VERSION = 1.2;

# RHEL 8+ Compliant Inheritance
use parent qw(Cpanel::Config::ConfigObj::Interface::Config::Version::v1);

sub spec_version {
    return 1;
}

sub meta_version {
    return 1;
}

sub get_driver_name {
    return 'ConfigServercsf_driver';
}

sub content {
    my ($locale_handle) = @_;

    my $content = {
        'vendor'   => 'Revolutionary Technology',     # Updated from Jonathan Michaelson
        'url'      => 'https://configserver.shop',    # Updated URL
        'name'     => {
            'short'  => 'ConfigServer Security & Firewall',
            'long'   => 'ConfigServer Security & Firewall',
            'driver' => get_driver_name(),
        },
        'since'    => 'cPanel 11.38.1',
        'abstract' => "ConfigServer Security & Firewall",
        'version'  => $VERSION,
    };

    if ($locale_handle) {
        $content->{'abstract'} = $locale_handle->maketext("ConfigServer Security & Firewall");
    }

    return $content;
}

sub showcase {
    return;
}

1;