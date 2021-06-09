package PERLogger::Controller::Initial;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use DBUtils;
use Utils;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

# This action will render a template
sub welcome ($self) {
    $self->render();
}

sub test($self){
    $self->render();
}

sub servers ($self) {
    $self->render( json => DBUtils::get_servers_with_stats() );
}

sub serverlfiles ($self) {
    my $result = DBUtils::get_servers_and_log_files( $self->param('server') );
    $self->render( json => $result );
}

sub getlogs ($self) {
    my $params = decode_json( $self->req->body );
    my $where  = [];    #map { lhost => $_ } keys %{$params};
    foreach my $key ( keys %{$params} ) {
        push @{$where},
          {
            lhost_md5 => $key,
            lfile_md5 => $params->{$key}
          };
    }

    #print Dumper $where;

    $self->render( json => DBUtils::get_logs($where) );
}

sub client ($self){
    shift->reply->static('../lib/LoggerClient.pm') 
}

1;
