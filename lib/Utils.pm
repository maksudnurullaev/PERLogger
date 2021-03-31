package Utils;

use Mojo::Base -strict;
use Mojo::Home;

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

sub print_warn{
    _prefix_print( "WARNING", "yellow", $_[0]);
};

sub print_error{
    _prefix_print( "ERROR", "red", $_[0]);
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

1;
