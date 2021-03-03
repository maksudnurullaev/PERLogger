package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

# This method will run once at server start
sub startup ($self) {

  # Load configuration from config file
  my $config = $self->plugin('NotYAMLConfig');

  # Configure the application
  $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

  # MAIN Route
  $r->any(['GET','POST'],'/')->to(controller => 'initial', action => 'welcome', payload => undef);
}

1;
