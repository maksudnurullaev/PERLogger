package SSH;

use Mojo::Base -strict;
use Net::SSH::Perl;
use Utils;

sub _doCmd {
    my $server = shift;
    return ( -1, 'Paramaters not properly defined!' )
      if ref($server) ne 'HASH'
      || !exists( $server->{nameOrIp} )
      || !exists( $server->{userName} )
      || !exists( $server->{userPassword} )
      || !exists( $server->{commands} );
    my ( $ssh, $stdout, $stderr, $exit );
    $ssh =
      Net::SSH::Perl->new( $server->{nameOrIp},
        options => ["MACs +hmac-sha1"] );
    eval {
        $ssh->login( $server->{userName}, $server->{userPassword} );
        ( $stdout, $stderr, $exit ) = $ssh->cmd( $server->{commands} );
    };

    if ($@) {
        Utils::print_error $@;
        return ( 1, 'Internal error!' );
    }
    elsif ($exit) {
        Utils::print_error $stderr;
        return ( $exit, $stderr );
    }

    return ( 0, $stdout );
}

1;
