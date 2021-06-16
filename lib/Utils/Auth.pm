package Auth;

use Mojo::Base -strict;
use Data::Dumper;

sub getUserRoles {
    my ($self,$user_name) = (shift,lc(shift));
    return [] if !defined($user_name);

    my $users = $self->config->{users};

    for (@{$users}){
        return $_->{$user_name} if exists $_->{$user_name};
    }

    return [];   
}

1;
