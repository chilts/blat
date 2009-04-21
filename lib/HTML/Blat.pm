## ----------------------------------------------------------------------------
package HTML::Blat;

use strict;
use warnings;
use Data::Dumper;
use Carp;

use base qw(Class::Accessor);

use File::Find ();
use File::Basename;
use File::Glob ':glob';
use File::Slurp;
use Text::ScriptHelper qw( :all );
use Text::Phliky;
use Template;
use YAML qw( LoadFile );
use XML::Simple;
use JSON::Any;

__PACKAGE__->mk_accessors( qw(src_dir dest_dir template_dir dirs data) );

## ----------------------------------------------------------------------------

our $VERSION = '0.01';

sub go {
    my ($self) = @_;

    # firstly, check that all these dirs exist
    die "Source dir () doesn't exist" unless -d $self->src_dir;
    die "Destination dir () doesn't exist" unless -d $self->dest_dir;
    die "Template dir () doesn't exist" unless -d $self->template_dir;

    # get a list of all source directories
    $self->find_dirs();

    # read all the '.data.json' files that we can find in each src dir
    $self->read_site_data();

    # now process all the directories and their files
    $self->process();
}

sub find_dirs {
    my ($self) = @_;

    my $dir = $self->src_dir;

    my @dirs;
    File::Find::find( { wanted => sub { push @dirs, $File::Find::name if -d } }, $dir );
    @dirs = map { $_ eq '' ? '.' : qq{./$_} } map { s{ \A $dir/ }{}gxms && $_ } @dirs;
    # print Dumper( \@dirs );

    $self->dirs( \@dirs );
}

sub read_site_data {
    my ($self) = @_;

    my $src_dir = $self->src_dir();

    # get all the '.data.json' files from all directories encountered
    my $data = {};
    foreach my $dir ( @{ $self->dirs } ) {
        my $datafile = qq{$src_dir/$dir/.data.json};
        unless ( -f $datafile ) {
            # nothing there, so just make it blank
            $data->{$dir} = {};
            next;
        }

        my $j = JSON::Any->new();
        my $lines = read_file( $datafile );
        # save to our data stash
        $data->{$dir} = $j->jsonToObj( $lines );
    }
    $self->data( $data );
    # print Dumper( $self->data );
}

sub process {
    my ($self) = @_;

    foreach my $dir ( @{ $self->dirs } ) {
        $self->process_dir( $dir );
    }
}

sub process_dir {
    my ($self, $dir) = @_;
    sep();
    msg( qq{Processing '$dir' ...} );

    my $full_dir = $self->src_dir . qq{/$dir};

    my @filenames = $self->files_in_dir( $full_dir );
    unless ( @filenames ) {
        msg( qq{- no files found in $full_dir, skipping} );
        return;
    }

    # make sure the destination dir is there
    msg(q{Making .... '} . $self->dest_dir . qq{/$dir'});
    mkdir $self->dest_dir . qq{/$dir};

    foreach my $filename ( @filenames ) {
        my ($name, $path, $basename, $ext) = $self->parse_filename( $filename );

        line();
        msg('Filename: ' . $filename);

        # get the data we need to process this directory
        my $data = $self->dir_data_cumulative( $dir );

        my $html = $self->process_file( $dir, $filename, $data );
        unless ( defined $html ) {
            msg( qq{Didn't receive any html when processing '$filename'} );
            next;
        }

        my $dest_filename = $self->dest_dir . qq{/$dir/$basename.html};
        write_file( $dest_filename, $html );
        msg( qq{Written '$dest_filename' ... done} );
    }
    line();
}

sub dir_data_cumulative {
    my ($self, $dir) = @_;

    # let's make up the data needed for this directory
    my $data = {};
    while ( defined $dir ) {
        # msg( qq{t_dir=$dir} );

        my $this_data = $self->dir_data( $dir );
        %$data = (%$this_data, %$data);

        $dir = $self->next_dir_up( $dir );
    }

    return $data;
}

sub next_dir_up {
    my ($class, $dir) = @_;

    return undef if $dir eq '.';

    if ( $dir =~ m{ / }xms ) {
        $dir =~ s{  / [\w_-]+ \z }{}gxms;
    }
    else {
        $dir = '.';
    }
    return $dir;
}

sub dir_data {
    my ($self, $dir) = @_;
    return $self->{data}{$dir};
}

sub process_file {
    my ($self, $dir, $filename, $data) = @_;

    my $full_filename = $self->src_dir . qq{/$dir/$filename};

    my ($name, $path, $basename, $ext) = $self->parse_filename( $full_filename );
    my $local_data = {};

    # There are two types of files:
    # 1) Content
    # 2) Data
    #
    # Content files are processed with a data section at the top, but Data files
    # are just read in as pure data
    if ( $ext eq 'html' ) {
        # html files have data segments
        my $content;
        ($local_data, $content) = $self->read_data_content( $full_filename );

        # since this is already HTML, we're done making the main content
        $local_data->{content} = $content;
    }
    elsif ( $ext eq 'flk' ) {
        # flk files have data segments
        my $content;
        ($local_data, $content) = $self->read_data_content( $full_filename );

        # now convert Phliky into HTML
        my $phliky = Text::Phliky->new({ mode => 'basic' });
        $local_data->{content} = $phliky->text2html( $content );
    }
    elsif ( $ext eq 'json' ) {
        my $j = JSON::Any->new();
        my $lines = read_file( $full_filename );
        $local_data = $j->jsonToObj( $lines );
    }
    elsif ( $ext eq 'xml' ) {
        $local_data = XMLin( $full_filename );
    }
    elsif ( $ext eq 'yaml' ) {
        $local_data = LoadFile( $full_filename );
    }
    else {
        return;
    }

    # save the local data over the parent's data
    %$data = (%$data, %$local_data);

    unless ( defined $data->{template} ) {
        msg("No template found");
        return;
    }

    # now we can process this as normal since we have:
    # 1) html (in $local_data->{content})
    # 2) global $data

    # now we have both the data (may be empty) and the content (possibly blank)
    # so let's process the page if available
    my $html;
    my $template = Template->new({
        INCLUDE_PATH => $self->template_dir,
    });
    msg( qq{Template: $data->{template}} );
    $template->process( $data->{template}, $data, \$html )
        || die $template->error;

    return ($html);
}

sub read_data_content {
    my ($class, $filename) = @_;

    my $contents = read_file( $filename );
    # this should be done in a better way :)
    my ($data_block, $content) = split('-' x 79 . "\n", $contents, 2);

    unless ( defined $content ) {
        $content = $data_block;
        $data_block = '';
    }

    # get the JSON encoded data from the data portion
    my $j = JSON::Any->new();
    # save to our data stash
    my $data = $j->jsonToObj( $data_block );

    return ($data, $content);
}

## ----------------------------------------------------------------------------
# class (helper) methods
sub files_in_dir {
    my ($class, $dir) = @_;

    # find all the files in this dir
    my @filenames = bsd_glob( qq{$dir/*} );

    # only get the plan files (not directories)
    @filenames = grep { -f } @filenames;

    # remove backup filenames
    @filenames = grep { $_ !~ m{ ~ \z }xms } @filenames;

    # map all these on to just the src dir
    @filenames = map { s{ \A $dir/ }{}gxms && $_ } @filenames;
    return @filenames;
}

sub parse_filename {
    my ($class, $filename) = @_;
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
1;
## ----------------------------------------------------------------------------

=head1 NAME

B<HTML::Blat> - A static site generator

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Given a source, destination and template directory, Blat generates HTML from the input files found in the source directory.

 use HTML::Blat;
 
 $blat = HTML::Blat->new();
 $blat->src_dir( $src );
 $blat->dest_dir( $dest );
 $blat->template_dir( $template );
 
 $blat->go();

=head1 FUNCTIONS

=head2 function1

=head2 function2

=head1 BUGS

Please report any bugs or feature requests to C<bug-html-blat at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-Blat>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

 perldoc HTML::Blat

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML-Blat>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTML-Blat>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTML-Blat>

=item * Search CPAN

L<http://search.cpan.org/dist/HTML-Blat>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Andrew Chilton, all rights reserved.

This program is released under the following license: GPL3

=cut
