package Utils;

use Mojo::Base -strict;
use Mojo::Home;

use Term::ANSIColor;
use Digest::MD5 qw(md5_hex);

use Data::Dumper;

sub init_dir {
    my $home = Mojo::Home->new;
    $home->detect;
    my $path = $home->rel_file( $_[0] );
    my $dir  = $path->dirname();

    # ... check database directory existance
    if ( !-d $path->dirname ) {
        print_warn( "Directory $dir not exists, trying to create new one..." );
        make_path $dir
          or die "$!: Failed to create path: " . $dir;
    }

    return $_[1] ? $dir : $path;
};

sub print_info{
    _prefix_print( "   INFO", "green", $_[0] )
};

sub print_warn{
    _prefix_print( "WARNING", "yellow", $_[0] );
};

sub print_error{
    _prefix_print( " ERROR", "red", $_[0] );
};

sub _prefix_print {
    my ( $prefix, $color, $msg ) = @_;
    if ( $^O =~ /win/i ) {
        print sprintf( "[%s]: ", $prefix );
    }
    else {
        print colored( sprintf( "%s: ", $prefix ), $color );
    }
    say $msg;
}

sub dbResult2hash {
    my ($results,$key) = (shift,shift);
    my $dbResults = {};

    for my $hash (@{ $results->hashes }) {
        my %values = map { $_ => $hash->{$_} } @_ ;
        say Dumper \%values;
        if (!exists($dbResults->{$hash->{$key}})){
            $dbResults->{$hash->{$key}} = [\%values] ;
        } else {
            push @{$dbResults->{$hash->{$key}}}, \%values ;
        } 
    }

    return $dbResults;
}

sub md5{
    return substr(md5_hex(shift),shift,shift);
}



1;
