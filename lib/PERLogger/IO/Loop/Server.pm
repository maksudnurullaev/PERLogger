use Mojo::Base 'Mojo::IOLoop::Client';

use Errno 'EINPROGRESS';

sub _connect {
  my ($self, $args) = @_;

  my $handle;
  my $address = $args->{socks_address} || $args->{address};
  unless ($handle = $self->{handle} = $args->{handle}) {
    my %options = (PeerAddr => $address, PeerPort => $args->{socks_port} || $args->{port}, Proto => 'udp');
    %options = (PeerAddrInfo => $args->{addr_info}) if $args->{addr_info};
    $options{Blocking} = 0;
    $options{LocalAddr} = $args->{local_address} if $args->{local_address};
    return $self->emit(error => "Can't connect: $@")
      unless $self->{handle} = $handle = IO::Socket::IP->new(%options);
  }
  $handle->blocking(0);

  # Wait for handle to become writable
  weaken $self;
  $self->reactor->io($handle => sub { $self->_ready($args) })
    ->watch($handle, 0, 1);
}

sub _ready {
  my ($self, $args) = @_;

  # Retry or handle exceptions
  my $handle = $self->{handle};
  return $! == EINPROGRESS ? undef : $self->emit(error => $!)
    if $handle->isa('IO::Socket::IP') && !$handle->connect;
  return $self->emit(error => $! || 'Not connected') unless $handle->connected;

  return $self->_cleanup->emit(connect => $handle);
}

1;