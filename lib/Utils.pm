package Utils;

use Mojo::Base -strict;
use Mojo::Home;

use Term::ANSIColor;
use Digest::MD5 qw(md5_hex);
use Time::Piece;
use Data::UUID;

use Data::Dumper;

sub init_path {
    my $home = Mojo::Home->new;
    $home->detect;
    my $path = $home->rel_file( shift );
    my $dir  = $path->dirname();

    # ... check database directory existance
    if ( !-d $path->dirname ) {
        print_warn("Directory $dir not exists, trying to create new one...");
        make_path $dir
          or die "$!: Failed to create path: " . $dir;
    }

    return shift ? $dir : $path;
}

sub print_info {
    _prefix_print( "   INFO", "green", $_[0] );
}

sub print_warn {
    _prefix_print( "WARNING", "yellow", $_[0] );
}

sub print_error {
    _prefix_print( " ERROR", "red", $_[0] );
}

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

sub hashesGroupBy {
    my ( $hashes, $key ) = ( shift, shift );
    my $result = {};

    for my $hash ( @{$hashes} ) {
        my @keys   = grep { $_ !~ /$key/ } keys( %{$hash} );
        my %values = map  { $_ => $hash->{$_} } @keys;
        if ( !exists( $result->{ $hash->{$key} } ) ) {
            $result->{ $hash->{$key} } = [ \%values ];
        }
        else {
            push @{ $result->{ $hash->{$key} } }, \%values;
        }
    }

    if(@_){
        my $subKey = shift;
        for (keys %{$result}){
            $result->{ $_ } = hashesGroupBy($result->{ $_ }, $subKey, @_);
        }
    }

    return $result;
}

sub md5 {
    return substr( md5_hex(shift), shift, shift );
}

sub get_uuid {
    my $ug = new Data::UUID;
    my $uuid = $ug->create;
    my @result = split('-',$ug->to_string($uuid));
    return($result[0]);
};

sub get_date_uuid {
    my $result= Time::Piece->new->strftime('%Y.%m.%d %T ');
    return($result . get_uuid());
};

sub trim{
    my $string = $_[0];
    if(defined($string) && $string){
        $string =~ s/^\s+|\s+$//g;
        return($string);
    }
    return(undef);
};

1;
