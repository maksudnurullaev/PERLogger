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

my $dryRunMode = 0;

sub ping ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    my $p = Net::Ping->new();
    eval { $p->ping( $data->{nameOrIp}, $data->{taskTimeout} ) };
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
      Net::SSH::Perl->new( $data->{nameOrIp}, options => ["MACs +hmac-sha1"] );
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

sub delServer ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $data = decode_json( $self->req->body );

    my $sql_string = qq{
DELETE
FROM objects
WHERE ID in
    (SELECT DISTINCT ID
     FROM objects
     WHERE ? in (ID, VALUE) ); 
    };

    my $dbh = $self->dbMain->get_db_connection();
    my $sth = $dbh->prepare($sql_string);
    $sth->execute( $data->{server} );

    $self->render( json => { status => 0, msg => "Server deleted!" } );
}

sub delUsers ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $data = decode_json( $self->req->body );

    for my $uid ( @{ $data->{users} } ) {
        $self->dbMain->del_link( $data->{server}, $uid );
        $self->dbMain->del($uid);
    }
    $self->render( json => { status => 0, msg => "Updated!" } );

}

sub saveUser4Server ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $data = decode_json( $self->req->body );

    if ( exists( $data->{_sid} ) && $data->{_sid} ) {
        my $_uData = {
            object_name => $SERVER_USER_INFO_OBJECT_NAME,
            user        => $data->{userName},
            owner       => $self->session->{'user.name'},
            password    => EnDeCrypt::encryptMe( $data->{userPassword} ),
        };

        # save && create link
        my $uId = $self->dbMain->insert( $_uData, $dryRunMode );
        $self->dbMain->set_link( $data->{_sid}, $uId, $dryRunMode );

        if ($dryRunMode) {
            $self->render( json => { status => 1, msg => "Dry run mode!" } );
        }
        else {
            $self->render(
                json => { status => 0, msg => "New user created!" } );
        }
    }
    else {
        $self->render(
            json => { status => 1, msg => "Server not defined to add user!" } );
    }

}

sub saveServer ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    my $_sData = {
        object_name => $SERVER_INFO_OBJECT_NAME,
        nameOrIp    => $data->{nameOrIp},
        description => $data->{description},
    };

    my $sId;

    # update server
    if ( exists( $data->{id} ) && $data->{id} ) {
        $_sData->{id} = $data->{id};
        $sId = $self->dbMain->update( $_sData, $dryRunMode );
        $self->render(
            json => { status => 0, msg => "Server [$sId] updated!" } );
    }
    else {    #insert new server
        $_sData->{owner} = $self->session->{'user.name'};
        $sId = $self->dbMain->insert( $_sData, $dryRunMode );

        # save server's user
        if (   exists( $data->{userName} )
            && $data->{userName}
            && exists( $data->{userPassword} )
            && $data->{userPassword} )
        {
            my $_uData = {
                object_name => $SERVER_USER_INFO_OBJECT_NAME,
                user        => $data->{userName},
                owner       => $self->session->{'user.name'},
                password    => EnDeCrypt::encryptMe( $data->{userPassword} ),
            };

            # save && create link
            my $uId = $self->dbMain->insert( $_uData, $dryRunMode );
            $self->dbMain->set_link( $sId, $uId, $dryRunMode );
        }
        $self->render(
            json => { status => 0, msg => "New server [$sId] created!" } );
    }

    if ($dryRunMode) {
        $self->render( json => { status => 1, msg => "Dry run mode!" } );
    }

}

sub getServersInfo ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $filter = {
        name    => [$SERVER_INFO_OBJECT_NAME],
        field   => ['owner'],
        value   => [ $self->session->{'user.name'} ],
        columns => [ 'nameOrIp', 'description' ]
    };

    my $servers = $self->dbMain->get_objects($filter);

    if ($servers) {
        for my $_key ( keys %{$servers} ) {
            if (
                my $_users = $self->dbMain->get_links(
                    $_key, $SERVER_USER_INFO_OBJECT_NAME,
                    [ 'user', 'owner' ]
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
