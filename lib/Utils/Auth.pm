package Auth;

use Mojo::Base -strict;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

sub login {
    my ( $self, $params ) = @_;
    return { status => 1, error_msg => "No controller!" } if !defined($self);
    return { status => 2, error_msg => "No parameters passed!" }
      if !defined($params);
    return { status => 3, error_msg => "No user.name passed!" }
      if !defined( $params->{'user.name'} );
    return { status => 4, error_msg => "No user.password passed!" }
      if !defined( $params->{'user.password'} );

    my $passcode = getPasscode( $self, $params->{'user.name'} );

    return { status => 5, error_msg => "No passcode definition!" }
      if !$passcode;

    return { status => 9, error_msg => "Password verification failed!" }
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

sub hasRole {
    my $self = shift;
    return 0 if !$self->session->{'user.name'} or !scalar(@_);

    my $roles = getUserRoles( $self, $self->session->{'user.name'} );
    for my $role (@_) {
        for ( @{$roles} ) {
            return 1 if $_ eq $role;
        }
    }

    return 0;
}

sub as {
    my $self = shift;
    return 0 if !@_;
    say "@_";
    $self->render( json => { status => 401, error_msg => 'You not authorized!' } )
      and return 0
      if !hasRole( $self, @_ );
    return 1;
}

1;
