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
  $self->render( json => [$self->param('server'),'1','2','3','4']);
}


1;
