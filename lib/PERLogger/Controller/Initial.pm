package PERLogger::Controller::Initial;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use DBUtils;
use Utils;

use Data::Dumper;

# This action will render a template
sub welcome ($self) {
  #$self->render();
}

sub servers ($self) {
  $self->render( json => DBUtils::get_servers_with_stats());
}

sub serverlfiles($self) {
  my $result = DBUtils::get_servers_and_log_files($self->param('server'));
  $self->render( json => $result ); 
}


1;
