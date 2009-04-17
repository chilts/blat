## ----------------------------------------------------------------------------
package HTML::Blat;

use warnings;
use strict;
use warnings;
use Carp;
use base qw(Class::Accessor);

## ----------------------------------------------------------------------------

our $VERSION = '0.01';

sub go {
    my ($self) = @_;

    # firstly, check that all these dirs exist
    die "Source dir () doesn't exist" unless -d $self->src_dir;
    die "Destination dir () doesn't exist" unless -d $self->dest_dir;
    die "Template dir () doesn't exist" unless -d $self->template_dir;

    # get a list of all source directories
    $self->find_source_dirs();

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
    @dirs = map { s{ \A $dir/ }{}gxms && $_ } @dirs;

    $self->dirs( \@dirs );
}

sub read_site_data {
    my ($self) = @_;

    $self->{data} = {};
    my $src_dir = $self->src_dir;

    # get all the '.data.json' files from all directories encountered
    my $gdata = {};
    foreach my $dir ( @{ $self->dirs } ) {
        print "$dir\n";
        next unless -f "$src_dir/$dir/.data.json";

        my $j = JSON::Any->new();
        my $lines = read_file( "$args->{src}/$dir/.data.json" );
        # save to our data stash
        $self->{data}{$dir} = $j->jsonToObj( $lines );
    }
    
}

sub process {
    my ($self) = @_;

    foreach my $dir ( @{ $self->dirs} ) {
        process_dir( $dir );
    }
}

sub process_dir {
    my ($self, $dir) = @_;
    my $full_dir = $self->src_dir . qq{/$dir};
    # title( $full_dir );

    my @filenames = $self->files_in_dir( $full_dir );
    return unless @filenames;

    # get the data we need to process this directory
    my $data = $self->get_site_data( $dir );
    
    foreach my $filename ( @filenames ) {
        my ($data, $content) = $self->process_file( $dir, $filename );
        next unless defined $content;
        $data->{content} = $content;

        my ($name, $path, $basename, $ext) = $self->fileparse( $filename );

        my $template = Template->new();
        my $dest_filename = $self->dest_dir . qq{/$dir/$basename.html};
        $template->process( $self->template_dir . qq{/index.html}, $data, $dest_filename );
        field( 'Written', $dest_filename );

        msg();
    }
}


sub process_file {
    my ($self, $dir, $filename) = @_;

    # nothing to do with directories
    return if -d $filename;

    # ignore backup files
    return if $filename =~ m{ ~ \z }xms;

    my ($name, $path, $basename, $ext) = my_fileparse( $args, $filename );
    field('Found', $name);
    field('Basename', $basename);
    field('Ext', $ext);
    my ($data, $content);
    my $template = Template->new({
        INCLUDE_PATH => $args->{lib},
    });
    my $full_filename = qq{$args->{src}/$dir/$filename};

    # let's process it in the correct way
    if ( $ext eq 'html' ) {
        # read the file in and split off the data portion
        my $tmp_content;
        ($data, $tmp_content) = read_content_file( qq{$args->{src}/$dir/$filename} );
        # template in the data to the content
        $template->process( \$tmp_content, $data, \$content );
    }
    elsif ( $ext eq 'flk' ) {
        # read the file in and split off the data portion
        ($data, $content) = read_content_file( qq{$args->{src}/$dir/$filename} );
        # now convert Phliky into HTML
        my $phliky = Text::Phliky->new({ mode => 'basic' });
        $content = $phliky->text2html( $content );
        # template in the data to the content
        $template->process( \$content, $data, \$content );
    }
    elsif ( $ext eq 'xml' ) {
        $data = XMLin( $full_filename );
        $template->process( $data->{template}, $data, \$content );
    }
    elsif ( $ext eq 'yaml' ) {
        $data = LoadFile( $full_filename );
        $template->process( $data->{template}, $data, \$content );
    }
    elsif ( $ext eq 'json' ) {
        my $j = JSON::Any->new();
        my $lines = read_file( $full_filename );
        $data = $j->jsonToObj( $lines );
        $template->process( $data->{template}, $data, \$content );
    }
    else {
        return;
    }
    return ($data, $content);
}


## ----------------------------------------------------------------------------
# class (helper) methods
sub files_in_dir {
    my ($class, $dir) = @_;
    # find all the files in this dir
    my @filenames = bsd_glob( qq{$dir/*} );
    @filenames = grep { -f } @filenames;
    @filenames = map { s{ \A $dir/ }{}gxms && $_ } @filenames;
    return @filenames;
}

sub fileparse {
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
