#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;

use Data::Dumper;
use Getopt::Mixed "nextOption";

use HTML::Blat;

my @IN_OPTS = qw(
                  src=s      s>src
                  dest=s     d>dest
                  template=s t>template
                  verbose    v>verbose
                  help
                  version
);

use constant BOOLEAN_ARGS => {
    verbose => 1,
    debug   => 1,
    help    => 1,
    version => 1
};

use constant VERSION => '0.1';

## ----------------------------------------------------------------------------

MAIN: {
    my $args = {};
    Getopt::Mixed::init( @IN_OPTS );
    while( my($opt, $val, $pretty) = nextOption() ) {
        $args->{$opt} = exists BOOLEAN_ARGS->{$opt} ? 1 : $val;
    }
    Getopt::Mixed::cleanup();

    # do the version and help
    if ( exists $args->{version} ) {
        print "$0 ".VERSION."\n";
        exit;
    }

    if ( exists $args->{help} ) {
        usage();
        exit;
    }

    # remove trailing '/' then check these three directories exist
    $args->{src} =~ s{ \/* \z }{}gxms;
    $args->{dest} =~ s{ \/* \z }{}gxms;
    $args->{template} =~ s{ \/* \z }{}gxms;

    unless ( defined $args->{src} && -d $args->{src} ) {
        Getopt::Mixed::abortMsg('specify a source directory')
    }
    unless ( defined $args->{dest} && -d $args->{dest} ) {
        Getopt::Mixed::abortMsg('specify a destination directory')
    }
    unless ( defined $args->{template} && -d $args->{template} ) {
        Getopt::Mixed::abortMsg('specify a lib (template) directory')
    }

    # all input params checked, now get on with the program
    my $blat = HTML::Blat->new();

    $blat->src_dir( $args->{src} );
    $blat->dest_dir( $args->{dest} );
    $blat->template_dir( $args->{template} );

    $blat->go();
}

## ----------------------------------------------------------------------------
