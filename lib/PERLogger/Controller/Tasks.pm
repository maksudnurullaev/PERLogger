package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

my $LOG_CONFIG_OBJECT_NAME = 'LOG_CONFIG';

sub ping ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    $self->render(
        json => { status => 0, servers => 'DBLogs::get_servers_with_stats()' } );
}

1;
