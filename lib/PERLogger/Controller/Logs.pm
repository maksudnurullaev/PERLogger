package PERLogger::Controller::Logs;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

my $LOG_CONFIG_OBJECT_NAME = 'LOG_CONFIG';

sub servers ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $results = DBLogs::get_servers_with_stats();

    if ( @{$results} ) {
        $self->render( json => { status => 0, servers => $results } );
    }
    else {
        $self->render( json => { status => 1, msg => "Servers not found!" } );
    }
}

sub serverlfiles ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $result = DBLogs::get_servers_and_log_files( $self->param('server') );
    $self->render( json => $result );
}

sub get ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $params = decode_json( $self->req->body );

    if ( !exists( $params->{where} ) ) {
        $self->render(
            json => { status => 1, msg => "NO WHERE definitions!" } );
    }
    elsif ( !exists( $params->{top} ) ) {
        $self->render( json => { status => 2, msg => "NO TOP definitions!" } );
    }
    else {
        my $where = [];
        for ( @{ $params->{where} } ) {
            push @{$where}, $_;
        }

        $self->render(
            json => {
                status => 0,
                logs   => DBLogs::get_logs( $where, $params->{top} )
            }
        );

    }
}

sub configSave ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    $data->{object_name} = $LOG_CONFIG_OBJECT_NAME;
    $data->{owner}       = $self->session->{'user.name'};
    my $newId =
      ( exists( $data->{id} ) and $data->{id} )
      ? $self->dbMain->update($data)
      : $self->dbMain->insert($data);

    $self->render(
        json => {
            status => 0,
            id     => $newId,
        }
    );
}

sub configDel ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $data = decode_json( $self->req->body );
    print "Delete logConfig id: " . $data->{id} . "\n";
    my $delId = $self->dbMain->del( $data->{id} );

    $self->render(
        json => {
            status => 0,
            id     => $delId,
        }
    );
}

sub configs ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $configs = $self->dbMain->get_objects(
        {
            name  => [$LOG_CONFIG_OBJECT_NAME],
            field => [qw/error_defs warning_defs name/]
        }
    );
    if ($configs) {
        $self->render(
            json => {
                status  => 0,
                configs => $configs
            }
        );
    }
    else {
        $self->render(
            json => {
                status    => 1,
                msg => "Configurations not found!"
            }
        );
    }
}

1;
