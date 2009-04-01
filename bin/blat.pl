#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Mixed "nextOption";
use File::Find ();
use File::Basename;
use File::Glob ':glob';
use File::Slurp;
use Text::ScriptHelper qw( :all );
use Text::Phliky;
use Template;

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
    $args->{src} =~ s{ \/* \z }{}gxms;
    $args->{dest} =~ s{ \/* \z }{}gxms;
    $args->{lib} =~ s{ \/* \z }{}gxms;

    unless ( defined $args->{src} && -d $args->{src} ) {
        Getopt::Mixed::abortMsg('specify a source directory')
    }
    unless ( defined $args->{dest} && -d $args->{dest} ) {
        Getopt::Mixed::abortMsg('specify a destination directory')
    }
    unless ( defined $args->{lib} && -d $args->{lib} ) {
        Getopt::Mixed::abortMsg('specify a lib (template) directory')
    }

    my @dirs = all_dirs_from_here( $args->{src} );
    foreach my $dir ( @dirs ) {
        process_dir( $args, $dir );
    }

    line();

    exit;
}

## ----------------------------------------------------------------------------
# methods

sub process_dir {
    my ($args, $dir) = @_;

    my $full_dir = qq{$args->{src}/$dir};
    title( $full_dir );

    my $cfg = {};
    if ( -e qq{$full_dir/.blat.yaml} ) {
        msg( q{Found a .blat.yaml file here} );
    }

    my @filenames = files_in_dir( $full_dir );

    unless ( @filenames ) {
        msg( q{No files found!} );
        return;
    }

    foreach my $filename ( @filenames ) {
        my ($data, $content) = process_content( $args, $dir, $filename );
        next unless defined $content;
        $data->{content} = $content;

        my ($name, $path, $basename, $ext) = my_fileparse( $filename );

        # $template->process( \$output, $data, qq{$args->{dest}/$dir/$basename.html});
        # print Dumper($data);
        my $template = Template->new();
        $template->process( qq{$args->{lib}/wrapper.thtml}, $data, qq{$args->{dest}/$dir/$basename.html} );
        field( 'Written', qq{$args->{dest}/$dir/$basename.html} );

        msg();
    }

    # msg( qq{... done} );
}

sub process_content {
    my ($args, $dir, $filename) = @_;

    # nothing to do with directories
    return if -d $filename;

    # ignore backup files
    return if $filename =~ m{ ~ \z }xms;

    my ($name, $path, $basename, $ext) = my_fileparse( $filename );
    field('Found', $name);
    field('Basename', $basename);
    field('Ext', $ext);

    my $template = Template->new({
        INCLUDE_PATH => $args->{lib},
    });

    # read the file in and split off the data portion
    my ($data, $content) = read_content_file(qq{$args->{src}/$dir/$filename});

    # let's process it in the correct way
    if ( $ext eq 'html' ) {
        # nice and simple, it's already HTML
    }
    elsif ( $ext eq 'flk' ) {
        my $phliky = Text::Phliky->new({ mode => 'basic' });
        $content = $phliky->text2html( $content );
    }
    elsif ( $ext eq 'xml' ) {
        #msg( q{Doing an XML file} );
    }
    elsif ( $ext eq 'yaml' ) {
        #msg( q{Doing a YAML file} );
    }

    my $html;
    $template->process( \$content, $data, \$html );
    return ($data, $html);
}

sub read_content_file {
    my ($filename) = @_;

    my $contents = read_file( $filename );
    my ($data_block, $content) = split('-' x 79 . "\n", $contents, 2);

    unless ( defined $content ) {
        $content = $data_block;
        $data_block = '';
    }

    my $data = {};

    # figure out what kind of data this is
    if ( 1 ) {
        my @lines = split(/\n/, $data_block);
        foreach my $line ( @lines ) {
            my ($key, $value) = $line =~ m{ \A (\w+)\s*:\s+(.*) \z }xms;
            $data->{$key} = $value;
        }
    }

    return ($data, $content);
}

## ----------------------------------------------------------------------------
# helpers for finding dirs, files and manipulating filenames

sub all_dirs_from_here {
    my ($dir) = @_;

    my @dirs;
    File::Find::find( { wanted => sub { push @dirs, $File::Find::name if -d } }, $dir );
    @dirs = map { s{ \A $dir/ }{}gxms && $_ } @dirs;

    return @dirs;
}

sub files_in_dir {
    my ($dir) = @_;

    # find all the files in this dir
    my @filenames = bsd_glob( qq{$dir/*} );
    @filenames = grep { -f } @filenames;
    @filenames = map { s{ \A $dir/ }{}gxms && $_ } @filenames;
    return @filenames;
}

sub my_fileparse {
    my ($filename) = @_;

    my ($name, $path, $basename, $ext);

    # get the main filename and it's path first
    ($name, $path) = fileparse( $filename );

    # now try for it's real basename and it's extension
    unless ( ($basename, $ext) = $name =~ m{ \A (.*) \. (\w+) \z }xms ) {
        $basename = $name;
        $ext = '';
    }
    return ($name, $path, $basename, $ext);
}

## ----------------------------------------------------------------------------
