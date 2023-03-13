package PERLogger::Controller::Program;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

my $PROGRAM_INFO_OBJECT_NAME = 'PROGRAM_INFO';

my $dryRunMode = 0;

sub save ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $data = decode_json( $self->req->body );

    # update existance
    if ( exists( $data->{id} ) && $data->{id} ) {
        $self->dbMain->update( $data, $dryRunMode );
        $self->render( json => { status => 0, msg => "Program updated!" } );
    }
    else {    #insert - new
        $data->{object_name} = $PROGRAM_INFO_OBJECT_NAME;
        $data->{owner}       = $self->session->{'user.name'};
        $self->dbMain->insert( $data, $dryRunMode );

        $self->render( json => { status => 0, msg => "Program created!" } );
    }

    if ($dryRunMode) {
        $self->render( json => { status => 1, msg => "Dry run mode!" } );
    }

}

sub all ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $filter = {
        name    => [$PROGRAM_INFO_OBJECT_NAME],
        field   => ['owner'],
        value   => [ $self->session->{'user.name'} ],
        columns => ['name']
    };

    my $commands = $self->dbMain->get_objects($filter);
    if ($commands) {
        $self->render(
            json => {
                status   => 0,
                commands => $commands
            }
        );
    }
    else {
        $self->render(
            json => {
                status => 1,
                msg    => "Commands not found!"
            }
        );
    }
}

sub info ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );
    my $data = decode_json( $self->req->body );

    my $filter = {
        name    => [$PROGRAM_INFO_OBJECT_NAME],
        field   => ['owner'],
        value   => [ $self->session->{'user.name'} ],
        id      => $data->{ids},
        columns => [ 'name', 'commands', 'description' ],
    };

    my $commands = $self->dbMain->get_objects($filter);
    if ($commands) {
        $self->render(
            json => {
                status   => 0,
                commands => $commands
            }
        );
    }
    else {
        $self->render(
            json => {
                status => 1,
                msg    => "Commands not found!"
            }
        );

    }
}

1;
