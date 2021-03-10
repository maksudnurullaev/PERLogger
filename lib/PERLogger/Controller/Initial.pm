package PERLogger::Controller::Initial;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# This action will render a template
sub welcome ($self) {
  #$self->render();
}

sub servers ($self) {
  my %servers;
  foreach (1..12) {
    $servers { "server - $_" } = $_ ;
  }

  $self->render( json => \%servers)
}


1;
