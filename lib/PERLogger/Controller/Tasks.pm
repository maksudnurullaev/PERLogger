package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);
use Net::Ping;
use Net::SSH::Perl;
use Data::Dumper;
use Utils::EnDeCrypt;

my $SERVER_INFO_OBJECT_NAME = 'SERVER_INFO';

sub ping ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    my $p = Net::Ping->new();
    eval { $p->ping( $data->{nameOrIP}, $data->{taskTimeout} ) };
    if ( !$@ ) {
        $self->render( json => { status => 0, msg => 'Ping passed!' } );
    }
    else {
        $self->render( json => { status => 1, msg => $@ } );
    }
    $p->close();

}

sub pingSsh ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    my ( $ssh, $stdout, $stderr, $exit );
    $ssh =
      Net::SSH::Perl->new( $data->{nameOrIP}, options => ["MACs +hmac-sha1"] );
    eval {
        $ssh->login( $data->{userName}, $data->{userPassword} );
        ( $stdout, $stderr, $exit ) = $ssh->cmd("uname -a");
    };

    if ($@) {
        $self->render( json => { status => 1, msg => 'Permission denied!' } );
        Utils::print_error $@;
    }
    elsif ($exit) {
        $self->render( json => { status => $exit, msg => $stderr } );
        Utils::print_error $stderr;
    }
    else {
        $self->render( json => { status => 0, msg => "OK: $stdout" } );
    }
}

sub saveServer ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    $data->{name} = $SERVER_INFO_OBJECT_NAME;
    $data->{owner}       = $self->session->{'user.name'};

    # encrypt password
    $data->{userPassword} = EnDeCrypt::encryptMe( $data->{userPassword} )
      if exists( $data->{userPassword} )
      and $data->{userPassword};

    # Utils::print_debug EnDeCrypt::decryptMe($data->{userPassword});
    my $id =
      ( exists( $data->{id} ) and $data->{id} )
      ? $self->dbMain->update($data)
      : $self->dbMain->insert($data);

    $self->render(
        json => { status => 0, msg => "New server [$id] created!" } );
}

sub getServersInfo ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $filter = {
        name  => [$SERVER_INFO_OBJECT_NAME],
        #owner => $self->session->{'user.name'}
    };

    my $objects = $self->dbMain->get_objects($filter);

    Utils::print_debug Dumper $objects;

    $self->render( json => { status => 1, msg => "Not impelemented yet!" } );

}

1;
