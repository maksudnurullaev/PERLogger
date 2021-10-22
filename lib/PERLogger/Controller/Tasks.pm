package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);
use Net::Ping;
use Net::SSH::Perl;
use Data::Dumper;
use Utils::EnDeCrypt;

my $SERVER_INFO_OBJECT_NAME      = 'SERVER_INFO';
my $SERVER_USER_INFO_OBJECT_NAME = 'SERVER_USER_INFO';

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

    my $_sData = {
        object_name => $SERVER_INFO_OBJECT_NAME,
        nameOrIP    => $data->{nameOrIP},
        description => $data->{description},
        owner       => $self->session->{'user.name'}
    };
    $_sData->{id} = $data->{id} if exists( $data->{_id} ) && $data->{_id};

    # save server
    my $sId =
      exists( $_sData->{id} )
      ? $self->dbMain->update($_sData)
      : $self->dbMain->insert($_sData);

    # save server's user
    if ( exists( $data->{userName} ) && $data->{userName} ) {
        my $_uData = {
            object_name => $SERVER_USER_INFO_OBJECT_NAME,
            user        => $data->{userName},
            owner       => $self->session->{'user.name'}
        };
        $_uData->{userPassword} = EnDeCrypt::encryptMe( $data->{userPassword} )
          if exists( $data->{userPassword} ) && $data->{userPassword};

        # save server
        my $uId = $self->dbMain->insert($_uData);
        $self->dbMain->set_link( $sId, $uId );
    }

    $self->render(
        json => { status => 0, msg => "New server [$sId] created!" } );
}

sub _saveUser4Server ( $self, $serverId, $user, $password ) {

}

sub getServersInfo ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $filter = {
        name    => [$SERVER_INFO_OBJECT_NAME],
        field   => ['owner'],
        value   => [ $self->session->{'user.name'} ],
        columns => ['nameOrIp']
    };

    my $servers = $self->dbMain->get_objects($filter);

    if ($servers) {
        for my $_key ( keys %{$servers} ) {
            if (
                my $_users = $self->dbMain->get_links(
                    $_key, $SERVER_USER_INFO_OBJECT_NAME, ['user','owner']
                )
              )
            {
                $servers->{$_key}{users} = $_users;
            }
        }
        $self->render(
            json => {
                status  => 0,
                servers => $servers
            }
        );
        return;
    }

    $self->render(
        json => {
            status => 1,
            msg    => "Servers not found!"
        }
    );

}

1;
