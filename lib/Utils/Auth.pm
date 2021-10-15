package Auth;

use Mojo::Base -strict;
use Digest::MD5 qw(md5_hex);
use Utils;
use Data::Dumper;

sub login {
    my ( $self, $params ) = @_;
    return { status => 1, msg => "No controller!" } if !defined($self);
    return { status => 2, msg => "No parameters passed!" }
      if !defined($params);

    return {
        status    => 32,
        msg => "MSAD integration not implemented yet!"
      }
      if $params->{MSADUser};

    return { status => 3, msg => "No user name!" }
      if !defined( $params->{'user.name'} );
    return { status => 4, msg => "No user password!" }
      if !defined( $params->{'user.password'} );

    my $passcode = getPasscode( $self, $params->{'user.name'} );

    return { status => 5, msg => "No passcode definition!" }
      if !$passcode;

    return { status => 9, msg => "Password verification failed!" }
      if ( md5_hex( $params->{'user.password'} ) ne $passcode );

    $self->session->{'user.name'} = $params->{'user.name'};
    return {
        status => 0,
        roles  => getUserRoles( $self, $params->{'user.name'} )
    };
}

sub getUserRoles {
    my ( $self, $user_name ) = ( shift, lc(shift) );
    return [] if !defined($user_name);

    my $users = $self->config->{users};

    return []
      if !exists( $users->{$user_name} )
      or !exists( $users->{$user_name}{'access'} );

    return $users->{$user_name}{'access'};
}

sub getPasscode {
    my ( $self, $user_name ) = ( shift, lc(shift) );

    my $users = $self->config->{users};
    return ""
      if !exists( $users->{$user_name} )
      or !exists( $users->{$user_name}{'passcode'} );
    return $users->{$user_name}{'passcode'};
}

sub _hasRole {
    my $self = shift;

    my $roles = getUserRoles( $self, $self->session->{'user.name'} );
    Utils::print_debug( "AUTH: User from IP("
          . $self->tx->original_remote_address
          . ") and USER("
          . $self->session->{'user.name'}
          . ")\n" . "(Action/User) roles: (@_/@{$roles})" );
    for my $role (@_) {
        for ( @{$roles} ) {
            return 1 if $_ eq $role;
        }
    }

    return 0;
}

sub as {
    my $self = shift;
    $self->render(
        json => { status => 401, msg => 'You not authorized!' } )
      and return 0
      if !$self->session->{'user.name'} || !scalar(@_) || !_hasRole( $self, @_ );
    return 1;
}

1;
