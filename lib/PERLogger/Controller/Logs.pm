package PERLogger::Controller::Logs;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use DBUtils;
use Utils;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

sub servers ($self) {
    $self->render( json => DBUtils::get_servers_with_stats() );
}

sub serverlfiles ($self) {
    my $result = DBUtils::get_servers_and_log_files( $self->param('server') );
    $self->render( json => $result );
}

sub getlogs ($self) {
    my $params = decode_json( $self->req->body );

    if ( !exists( $params->{where} ) ) {
        $self->render(
            json => { status_code => 1, error_msg => "NO WHERE definitions!" } );
    }
    elsif ( !exists( $params->{top} ) ) {
        $self->render(
            json => { status_code => 0, error_msg => "NO TOP definitions!" } );
    }
    else {
        my $where = [];
        for ( @{ $params->{where} } ) {
            push @{$where}, $_;
        }

        $self->render(
            json => { status_code => 0, logs => DBUtils::get_logs($where, $params->{top}) } );

    }
}

sub client ($self) {
    shift->reply->static('../lib/LoggerClient.pm');
}

1;
