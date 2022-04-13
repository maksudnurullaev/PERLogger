package SSH;

use Mojo::Base -strict;

use Net::OpenSSH;
use Utils;
use Data::Dumper;
use Encode qw(decode encode);

sub _doCmd {
    my $server = shift;
    return ( -1, 'Paramaters not properly defined!' )
      if ref($server) ne 'HASH'
      || !exists( $server->{nameOrIp} )
      || !exists( $server->{userName} )
      || !exists( $server->{userPassword} )
      || !exists( $server->{commands} );

    my $ssh =
      Net::OpenSSH->new( $server->{userName} . ':'
          . $server->{userPassword} . '@'
          . $server->{nameOrIp} );
    my @out = $ssh->capture( $server->{commands} );
    my @outEncoded = map { decode('UTF-8', $_ , Encode::FB_CROAK) } @out;
    return ( 1, $ssh->error ) if $ssh->error;
    return ( 0, "@outEncoded");
}

1;
