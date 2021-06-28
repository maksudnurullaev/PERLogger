package PERLogger::Controller::User;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Utils::Auth;

use Data::Dumper;

sub login ($self) {
    my $params = decode_json( $self->req->body );

    $self->render( json => Auth::login( $self, $params ) );
}

sub current ($self) {
    if ( $self->session->{'user.name'} ) {
        $self->render(
            json => {
                status => 0,
                user   => $self->session->{'user.name'},
                roles  =>
                  Auth::getUserRoles( $self, $self->session->{'user.name'} )
            }
        );
    }
    else {
        $self->render(
            json => {
                status    => 1,
                error_msg => "NO authorization!"
            }
        );

    }
}

sub logout ($self) {
    $self->session( expires => 1 );
    $self->render( json => { status => 0 } );
}

1;
