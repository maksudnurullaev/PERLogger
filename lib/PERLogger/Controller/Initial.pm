package PERLogger::Controller::Initial;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# This action will render a template
sub welcome ($self) {

  # Render template "initial/welcome.html.ep" with message
  $self->render(msg => 'PERLogger');
}

1;
