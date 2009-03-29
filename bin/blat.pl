#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use File::Find ();
use Getopt::Mixed "nextOption";
use File::Glob qw(:glob);

my @IN_OPTS = qw(
                  src=s    s>src
                  dest=s   d>dest
                  lib=s    l>lib
                  verbose  v>verbose
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

    # check these three directories exist
    unless ( defined $args->{src} && -d $args->{src} ) {
        Getopt::Mixed::abortMsg('specify a source directory')
    }
    unless ( defined $args->{dest} && -d $args->{dest} ) {
        Getopt::Mixed::abortMsg('specify a destination directory')
    }
    unless ( defined $args->{lib} && -d $args->{lib} ) {
        Getopt::Mixed::abortMsg('specify a lib (template) directory')
    }

    my @dirs;
    File::Find::find( { wanted => sub { push @dirs, $File::Find::name if -d } }, $args->{src} );

    print "dirs=@dirs\n";

    foreach my $dir ( @dirs ) {
        process_dir( $dir, $args->{dest}, $args->{lib} );
    }

    exit;
}

## ----------------------------------------------------------------------------
# methods

sub process_dir {
    my ($src, $dest, $lib) = @_;

    v( qq{Dir '$src' ... });

    # firstly, see if there is a .blat.yaml file
    my $opts = {};
    if ( -e "$src/.blat.yaml" ) {
        v( q{Found '.blat.yaml' file} );
        # read in the options for this dir
    }

    # get all the files
    my @files = bsd_glob( "$src/*" );
    print "files=@files\n";

    foreach my $file ( @files ) {
        next if $file =~ m{ ~\z }xms;
        v("- $file");
    }
}

sub do_file {
    my ($dir, $file) = @_;
}

## ----------------------------------------------------------------------------

{
    my $verbose = 0;
    sub v {
        my ($msg) = @_;
        print qq{$msg\n};
    }
}
