package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

use Term::ANSIColor;
use Data::Dumper;

use Mojo::SQLite;
use Mojo::Home;
use Mojo::IOLoop::Subprocess;
use DBO;

use Utils;
use Utils::DBLogs;
use Utils::Auth;

use Utils::Logger::Server;

# This method will run once at server start
sub startup ($self) {

    $self->helper(
        'cache_control.no_caching' => sub ($c) {
            $c->res->headers->cache_control('private, max-age=0, no-cache');
        }
    );

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig');

    # Configure the application
    $self->secrets( $config->{secrets} );

    # Check configuration variables for database
    if ( !defined( $config->{path2LogsDb} ) ) {
        Utils::print_error(
"Not defined location for SQLite database file (path2LogsDb) in configuration file."
        );
        exit(1);
    }

    # Check & Configure database
    my $path2LogsDb = Utils::init_path( $config->{path2LogsDb} );

    # Setup db for logs
    $self->helper(
        dbLogs => sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2LogsDb ) }
    );

    # Inistilize databases
    # ... log database
    DBLogs::setup_sqlite $self->dbLogs ;
    # ... main database
    my $db = DBO->new($self, $self->config->{path2MainDb});
    $db->initialize() || die("Could not set initialize database!");
    $self->helper(
        dbMain => sub { state $dbMain = $db }
    );

    # Router
    $self->helper( authAs => sub { return Auth::as(@_) } );

    # MAIN Route
    my $r = $self->routes;
    $r->get('/')->to( controller => 'initial', action => 'start' );

    # API
    $r->get('/logs/servers')->to( controller => 'logs', action => 'servers' );
    $r->get('/logs/serverlfiles')
      ->to( controller => 'logs', action => 'serverlfiles' );
    $r->post('/logs/get')->to( controller => 'logs', action => 'get' );

    # static files
    $r->any('/client')->to(
        cb => sub {
            shift->reply->static('../lib/Utils/Logger/Client.pm');
        }
    );

    $r->post('/logs/config/new')->to( controller => 'logs', action => 'configNew' );
    $r->post('/logs/config/del')->to( controller => 'logs', action => 'configDel' );
    $r->get('/logs/configs')->to( controller => 'logs', action => 'configs' );


    # login
    $r->any('/user/login')->to( controller => 'user', action => 'login' );

    # logout
    $r->get('/user/logout')->to( controller => 'user', action => 'logout' );

    # get current user info
    $r->get('/user/current')->to( controller => 'user', action => 'current' );

    # test page
    $r->any('/test')->to( controller => 'logs', action => 'test' );

    # Run log file listener thread
    start_log_listener();
}

sub start_log_listener {
    Utils::print_info("Start log listener!");
    my $subprocess = Mojo::IOLoop::Subprocess->new;

    $SIG{INT} = $SIG{TERM} = sub {
        Utils::print_warn "-=Stop signal catched!=-\n";
        Server::stopServer();
    };

    $subprocess->run(
        sub ($subprocess) {
            Server::runServer( \&DBLogs::parse_it );

            #DEBUG: Server::runServer(\&Utils::print_warn) ;
            return '♥', 'Mojolicious';
        },
        sub ( $subprocess, $err, @results ) {
            say "Subprocess error: $err" and return if $err;
            say "I $results[0] $results[1]!";
        }
    );
}

1;
