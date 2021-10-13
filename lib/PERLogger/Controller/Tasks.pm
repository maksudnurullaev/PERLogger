package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);
use Net::Ping;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

my $LOG_CONFIG_OBJECT_NAME = 'LOG_CONFIG';

sub ping ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $params = decode_json( $self->req->body );

    my $p = Net::Ping->new();
    eval { $p->ping( $params->{nameOrIP}, $params->{taskTimeout} ) };
    if ( !$@ ) {
        $self->render( json => { status => 0 } );
    }
    else {
        $self->render(
            json => { status => 1, err_msg => 'Host unreachable!' } );
    }
    $p->close();

}

1;
