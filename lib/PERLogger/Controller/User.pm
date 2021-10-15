package PERLogger::Controller::User;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Utils::Auth;
use Net::LDAP::SPNEGO;

use Data::Dumper;

sub login ($self) {
    my $params = decode_json( $self->req->body );

    $self->render( json => Auth::login( $self, $params ) );
}

sub check ($self){
    # dummy method for user/check.html.ep file
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
                msg => "NO authorization!"
            }
        );

    }
}

sub logout ($self) {
    $self->session( expires => 1 );
    $self->render( json => { status => 0, msg => "You logged out!" } );
}

my %cCache;

sub detectAsMSADUser ($self) {
    my $c = shift;

    # once the user property is set, we are happy
    # and don't try to re-authenticate
    return $c->redirect_to('/') if $c->session('user.name');

    my $cId           = $c->tx->connection;
    my $cCache        = $cCache{$cId} //= { status => 'init' };
    my $authorization = $c->req->headers->header('Authorization') // '';
    my ($AuthBase64)  = ( $authorization =~ /^NTLM\s(.+)$/ );
    for ( $AuthBase64 and $cCache->{status} =~ /^expect(Type\d)/ ) {
        my $ldap = $cCache->{ldapObj} //=
          Net::LDAP::SPNEGO->new( $self->config->{MSADServer}, debug => 0 );
        $_ && /^Type1/ && do {
            my $mesg = $ldap->bind_type1($AuthBase64);
            if ( $mesg->{ntlm_type2_base64} ) {
                $c->res->headers->header( 'WWW-Authenticate' => 'NTLM '
                      . $mesg->{ntlm_type2_base64} );
                $c->render(
                    text   => 'Waiting for Type3 NTLM Token',
                    status => 401
                );
                $cCache->{status} = 'expectType3';
                return;
            }

            # lets try with a new connection
            $ldap->unbind;
            delete $cCache->{ldapObj};
        };
        $_ && /^Type3/ && do {
            my $mesg = $ldap->bind_type3($AuthBase64);
            if ( my $user = $mesg->{ldap_user_entry} ) {
                $c->session( 'user.name',     $user->{samaccountname} );
                $c->session( 'user.fullName', $user->{displayname} );
                my $groups = $ldap->get_ad_groups( $user->{samaccountname} );
                $c->session( 'user.groups', [ sort keys %$groups ] );
            }
            $ldap->unbind;
            delete $cCache->{ldapObj};
        };
    }
    $c->res->headers->header( 'WWW-Authenticate' => 'NTLM' );
    $c->render( text => 'Waiting for Type 1 NTLM Token', status => 401 );
    $cCache->{status} = 'expectType1';

}


1;
