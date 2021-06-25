package PERLogger::Controller::Logs;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DB;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

sub servers ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    $self->render(
        json => { status => 0, servers => DB::get_servers_with_stats() } );
}

sub serverlfiles ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $result = DB::get_servers_and_log_files( $self->param('server') );
    $self->render( json => $result );
}

sub get ($self) {
    return if !$self->authAs( 'log_operator', 'administrator' );

    my $params = decode_json( $self->req->body );

    if ( !exists( $params->{where} ) ) {
        $self->render(
            json => { status => 1, error_msg => "NO WHERE definitions!" } );
    }
    elsif ( !exists( $params->{top} ) ) {
        $self->render(
            json => { status => 0, error_msg => "NO TOP definitions!" } );
    }
    else {
        my $where = [];
        for ( @{ $params->{where} } ) {
            push @{$where}, $_;
        }

        $self->render( json =>
              { status => 0, logs => DB::get_logs( $where, $params->{top} ) } );

    }
}

1;
