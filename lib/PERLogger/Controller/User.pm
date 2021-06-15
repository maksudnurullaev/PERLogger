package PERLogger::Controller::User;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use DBUtils;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Digest::MD5 qw(md5_hex);
use Auth;

use Data::Dumper;

sub login ($self) {
    my $params = decode_json( $self->req->body );
    my $config = $self->config;

    if ( $params->{'user.name'} =~ /administrator/i
        && md5_hex( $params->{'user.password'} ) eq $config->{admin_password} )
    {
        $self->session->{'user.name'} = $params->{'user.name'};
        $self->render(
            json => { status_code => 0, roles => Auth::getUserRoles($self, $params->{'user.name'}) } );
    }
    else {
        $self->render( json =>
              { status_code => 1, status_text => 'Authentication failed!' } );
    }
}

sub current ($self) {
    if ( $self->session->{'user.name'} ) {
        $self->render(
            json => {
                status_code => 0,
                user        => $self->session->{'user.name'},
                roles        => Auth::getUserRoles($self, $self->session->{'user.name'})
            }
        );
    }
    else {
        $self->render(
            json => {
                status_code => 1,
                status_text => "NO authorization!"
            }
        );

    }
}

sub logout ($self) {
    $self->session( expires => 1 );
    $self->render( json => { status_code => 0 } );
}

1;
