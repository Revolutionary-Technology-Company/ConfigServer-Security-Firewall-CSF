package Cpanel::Config::ConfigObj::Driver::ConfigServercsf;

use strict;
use warnings;

# Import the META module so we can share the Version number
use Cpanel::Config::ConfigObj::Driver::ConfigServercsf::META ();

# Sync the version with META.pm so you only have to update it in one place
*VERSION = \$Cpanel::Config::ConfigObj::Driver::ConfigServercsf::META::VERSION;

# RHEL 8+ Compliant Inheritance
use parent qw(Cpanel::Config::ConfigObj::Interface::Config::v1);

sub init {
    my ( $class, $software_obj ) = @_;

    my $ConfigServercsf_defaults = {
        'thirdparty_ns' => "ConfigServercsf",
        'meta'          => {},
    };
    
    # Pass to parent class
    my $self = $class->SUPER::base( $ConfigServercsf_defaults, $software_obj );

    return $self;
}

sub enable {
    my ( $self, $input ) = @_;
    return 1;
}

sub disable {
    my ( $self, $input ) = @_;
    return 1;
}

sub info {
    my ($self)   = @_;
    my $meta_obj = $self->meta();
    
    # Grab abstract from META, fallback if missing
    my $abstract = $meta_obj->abstract() || 'ConfigServer Security & Firewall';
    return $abstract;
}

sub acl_desc {
    return [
        {
            # This MUST match the 'acls=' line in csf.conf
            'acl'              => 'software-ConfigServer-csf',       
            'default_value'    => 0,
            'default_ui_value' => 0,
            'name'             => 'ConfigServer Security & Firewall (Reseller UI)',
            'acl_subcat'       => 'Third Party Services',
        },
    ];
}

1;