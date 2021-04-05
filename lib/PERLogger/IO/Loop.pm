package PERLogger::IO::Loop;

use Mojo::Base 'Mojo::IOLoop';

use Scalar::Util 'weaken';

use PERLogger::IO::Loop::Server;

sub Server {
  my ($self, $cb) = (_instance(shift), pop);

  my $id = $self->_id;
  my $client = $self->{connections}{$id}{client} PERLogger::IO::Loop::Server->new;
  weaken $client->reactor($self->reactor)->{reactor};

  weaken $self;
  $client->on(
    connect => sub {
      delete $self->{connections}{$id}{client};
      my $stream = Mojo::IOLoop::Stream->new(pop);
      $self->_stream($stream => $id);
      $self->$cb(undef, $stream);
    }
  );
  $client->on(error => sub { $self->_remove($id); $self->$cb(pop, undef) });
  $client->connect(@_);

  return $id;
}

sub _instance { ref $_[0] ? $_[0] : $_[0]->singleton }

1;