package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Utils::EnDeCrypt;

use Data::Dumper;

sub runbatch ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my ( $data, $results ) = ( decode_json( $self->req->body ), [] );

    # Utils::print_debug Dumper $data;

    for my $su ( @{ $data->{servers} } ) {
        my $server = $self->dbMain->get_objects(
            { id => [ $su->{server} ], columns => ['nameOrIp'] } );
        if ( !$server || !exists( $server->{ $su->{server} }{nameOrIp} ) ) {
            Utils::print_error( "Server not found for ID: " . $su->{server} );
            next;
        }

        # 1. Get server
        my $server_nameOrIp = $server->{ $su->{server} }{nameOrIp};
        Utils::print_debug "server_nameOrIp: $server_nameOrIp";

        for my $u ( @{ $su->{users} } ) {

            my $user = $self->dbMain->get_objects(
                { id => [$u], columns => [ 'user', 'password' ] } );

            if (   !$user
                || !exists( $user->{$u}{user} )
                || !exists( $user->{$u}{password} ) )
            {
                Utils::print_error( "Proper user not found for ID: " . $u );
                next;
            }
            Utils::print_debug "User: " . $user->{$u}{user};

            # 2. Get user name & password
            my ( $user_name, $user_password ) = (
                $user->{$u}{user},
                EnDeCrypt::decryptMe( $user->{$u}{password} )
            );

            for my $cid ( @{ $data->{commands} } ) {
                my $prog = $self->dbMain->get_objects(
                    { id => [$cid], columns => [ 'commands', 'name' ] } );

                if ( !$prog || !exists( $prog->{$cid}{commands} ) ) {
                    Utils::print_error(
                        "Proper commands not found for ID: " . $cid );
                    next;
                }
                my ( $prog_commands, $prog_name ) =
                  ( $prog->{$cid}{commands}, $prog->{$cid}{name} );

#                 Utils::print_debug(
# "\n(server,user,passwod,commands): ($server_nameOrIp,$user_name, $user_password,$prog_commands)"
#                 );
                my ( $err_code, $result ) = SSH::_doCmd(
                    {
                        nameOrIp     => $server_nameOrIp,
                        userName     => $user_name,
                        userPassword => $user_password,
                        commands     => $prog_commands,
                    }
                );
                push @{$results}, {
                    errCode     => $err_code,
                    name        => "$server_nameOrIp/$user_name/$prog_name",
                    description => $result,
                    console     => 1    # preformated text
                };
                if ( !$err_code ) {
                    Utils::print_debug("OK: $result");
                }
                else {
                    Utils::print_error("Failed($err_code): $result");
                }

            }
        }
    }

    $self->render(
        json => { status => 0, msg => "Done!", results => $results } );

}

1;
