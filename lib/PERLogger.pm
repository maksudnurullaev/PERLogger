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

my $spid = 0;

# This method will run once at server start
sub startup ($self) {
    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig');

    # Logging
    my $path4Logging = Utils::init_path( $config->{path4Logging} );
    my $log          = Mojo::Log->new( path => $path4Logging );
    $self->app->log($log);
    Utils::set_logger($log);

    $self->helper(
        'cache_control.no_caching' => sub ($c) {
            $c->res->headers->cache_control('private, max-age=0, no-cache');
        }
    );

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
    $self->helper( dbLogs =>
          sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2LogsDb ) } );

    # Inistilize databases
    # ... log database
    DBLogs::setup_sqlite $self->dbLogs;

    # ... main database
    my $db = DBO->new( $self, $self->config->{path2MainDb} );
    $db->initialize() || die("Could not set initialize database!");
    $self->helper( dbMain => sub { state $dbMain = $db } );

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

    $r->post('/logs/config/save')
      ->to( controller => 'logs', action => 'configSave' );
    $r->post('/logs/config/del')
      ->to( controller => 'logs', action => 'configDel' );
    $r->get('/logs/configs')->to( controller => 'logs', action => 'configs' );

    # login
    $r->any('/user/login')->to( controller => 'user', action => 'login' );

    # logout
    $r->get('/user/logout')->to( controller => 'user', action => 'logout' );

    # get current user info
    $r->get('/user/current')->to( controller => 'user', action => 'current' );

    # tyr to detect MS AD authontication/user
    $r->get('/user/msad')
      ->to( controller => 'user', action => 'detectAsMSADUser' );

    # get current user info
    $r->get('/whoami')->to( controller => 'user', action => 'check' );

    # Run log file listener thread
    $self->app->hook(
        before_server_start => sub {
            $self->app->log->info('Start UPD listener!');

            # START UPD listener
            start_log_listener( $self->app->log );

            my ( $server, $app ) = @_;

            if ( $server->isa('Mojo::Server::Prefork') ) {
                $server->on(
                    finish => sub {
                        # STOP UDP listener
                        $self->app->log->info(
                            "Mojo::Server::Prefork: Stop UDP listener!");
                    }
                );
            }
            elsif ( $server->isa('Mojo::Server::Daemon') ) {
                $server->ioloop->on(
                    finish => sub {

                        # STOP UDP listener
                        $self->app->log->info(
                            "Mojo::Server::Daemon: Stop UDP listener!");
                    }
                );
            }
        }
    );
}

sub fix_stop_event4subprocces ( $subprocess, $log ) {
    $spid = $subprocess->pid;
    $log->info("Fix stop event for pid: $spid");
    $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {
        $log->warn("-=Stop signal catched!=-");
        $subprocess->ioloop->stop_gracefully;
        $log->warn("Send kill 'INT' signal to UPD server listener, PID: $spid ...");
        $log->warn("... killed!") if kill 'INT', $spid;
    };
}

sub start_log_listener ($log) {
    my $subprocess = Mojo::IOLoop::Subprocess->new;

    $subprocess->on(
        spawn => sub ($subprocess) {
            fix_stop_event4subprocces( $subprocess, $log );
        }
    );

    $subprocess->run(
        sub ($subprocess) {
            Server::runServer( \&DBLogs::parse_it );
        },
        sub ( $subprocess, $err, @results ) {
            $log->warn("Subprocess error: $err") and return if $err;
            $log->warn("I $results[0] $results[1]!");
        }
    );

}

1;
