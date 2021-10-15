package PERLogger::Controller::Tasks;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Utils;
use Utils::DBLogs;
use Mojo::JSON qw(decode_json encode_json);
use Net::Ping;
use Net::SSH::Perl;
use Data::Dumper;

my $LOG_CONFIG_OBJECT_NAME = 'LOG_CONFIG';

sub ping ($self) {
    return if !$self->authAs( 'shell_operator', 'administrator' );

    my $params = decode_json( $self->req->body );

    my $p = Net::Ping->new();
    eval { $p->ping( $params->{nameOrIP}, $params->{taskTimeout} ) };
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

    my $params = decode_json( $self->req->body );

    Utils::print_debug Dumper $params;

    my ( $ssh, $stdout, $stderr, $exit );
    $ssh = Net::SSH::Perl->new( $params->{nameOrIP},
        options => ["MACs +hmac-sha1"] );
    eval {
        $ssh->login( $params->{userName}, $params->{userPassword} );
        ( $stdout, $stderr, $exit ) = $ssh->cmd("uname -a");
    };

    if ($@) {
        $self->render( json => { status => 1, msg => $@ } );
    }
    elsif ($exit) {
        $self->render( json => { status => $exit, msg => $stderr } );
    }
    else {
        $self->render( json => { status => 0, msg => $stdout } );
    }
}

1;
