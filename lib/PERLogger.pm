package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

use Term::ANSIColor;
use Data::Dumper;

use Mojo::SQLite;
use Mojo::Home;
use Mojo::IOLoop::Subprocess;

use Utils;
use DBUtils;

use Logger;

# This method will run once at server start
sub startup ($self) {

    $self->helper(
        'cache_control.no_caching' => sub ($c) { $c->res->headers->cache_control('private, max-age=0, no-cache') }
    );
    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig');

    # Configure the application
    $self->secrets( $config->{secrets} );

    # Check configuration variables for database
    if ( !defined( $config->{dir4db} ) ) {
        Utils::print_error( "Not defined location for SQLite database file (dir4db) in configuration file." );
        exit(1);
    }

    # Check & Configure database
    my $path2db = Utils::init_dir($config->{dir4db});

    # Check directory for log files
    my $path2logs = Utils::init_dir($config->{dir4logs}, 1);

    # ... create helper for sqlite
    $self->helper(
        sqlite => sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2db ) }
    );

    # ... check for table existance
    my $db = $self->sqlite->db;

    if ( ! @{$db->tables} ) {
        for my $sql (DBUtils::get_init_sqls()) {
            my $sth = $db->dbh()->prepare($sql);
            $sth->execute() || die "$!";
            Utils::print_info("Executed initial SQL:" . $sql);
        }
    }

    # print Dumper $db->tables;
    # exit;
    # ... set db
    DBUtils::set_sqlite $self->sqlite;

    # Router
    my $r = $self->routes;

    # MAIN Route
    $r->get('/' )
      ->to( controller => 'initial', action => 'welcome');
    
    # API
    $r->get('/servers/')
      ->to( controller => 'initial', action => 'servers');
    $r->get('/serverlfiles/')
      ->to( controller => 'initial', action => 'serverlfiles');
    $r->post('/logs/')
      ->to( controller => 'initial', action => 'getlogs');

    # Run log file listener thread
    start_log_listener();
}

sub start_log_listener{
    Utils::print_info("Start log listener!");  
    my $subprocess = Mojo::IOLoop::Subprocess->new;
    
    $SIG{INT} = $SIG{TERM} = sub {
        Utils::print_warn "-=Stop signal catched!=-\n";
        Logger::stopServer() ;
    };

    $subprocess->run(
      sub ($subprocess) {
        Logger::runServer(\&DBUtils::parse_it) ;
        #Logger::runServer(\&Utils::print_warn) ;
        return '♥', 'Mojolicious';
      },
      sub ($subprocess, $err, @results) {
        say "Subprocess error: $err" and return if $err;
        say "I $results[0] $results[1]!";
      }
    );
}

1;
