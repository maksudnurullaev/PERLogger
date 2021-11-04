package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Utils::EnDeCrypt;

use Data::Dumper;

sub runbatch ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    Utils::print_debug Dumper $data;

    for my $su ( @{ $data->{servers} } ) {
        my $server = $self->dbMain->get_objects(
            { id => [ $su->{server} ], columns => ['nameOrIp'] } );
        if ( !$server || !exists( $server->{ $su->{server} }{nameOrIp} ) ) {
            Utils::print_error( "Server not found for ID: " . $su->{server} );
            next;
        }

        # 1. Get server
        my $server_nameOrIp = $server->{ $su->{server} }{nameOrIp};

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

            # 2. Get user name & password
            my ( $user_name, $user_password ) = (
                $user->{$u}{user},
                EnDeCrypt::decryptMe( $user->{$u}{password} )
            );

            for my $cid ( @{ $data->{commands} } ) {
                my $command = $self->dbMain->get_objects(
                    { id => [$cid], columns => ['commands'] } );

                if ( !$command || !exists( $command->{$cid}{commands} ) ) {
                    Utils::print_error(
                        "Proper commands found for ID: " . $cid );
                    next;
                }
                my $commands = $command->{$cid}{commands};
                Utils::print_debug(
"\n(server,user,passwod,commands): ($server_nameOrIp,$user_name, $user_password,$commands)"
                );
            }
        }
    }

    $self->render( json => { status => 1, msg => "Not implemented yet!" } );

}


1;
