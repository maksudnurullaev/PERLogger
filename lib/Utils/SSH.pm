package SSH;

use Mojo::Base -strict;
# use Net::SSH::Perl;
use Net::OpenSSH;
use Utils;
use Data::Dumper;

sub _doCmd {
    my $server = shift;
    return ( -1, 'Paramaters not properly defined!' )
      if ref($server) ne 'HASH'
      || !exists( $server->{nameOrIp} )
      || !exists( $server->{userName} )
      || !exists( $server->{userPassword} )
      || !exists( $server->{commands} );

    my $ssh = Net::OpenSSH->new($server->{userName}. ':' . $server->{userPassword} . '@' . $server->{nameOrIp});
    my ($out,$error) = $ssh->capture($server->{commands});
    return (1,$ssh->error)  if $ssh->error;
    return (0,$out);
};

1;
