package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

use Term::ANSIColor;
use Data::Dumper;

use Mojo::SQLite;
use Mojo::Home;

use Utils;

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

    Utils::print_warn $path2logs;

    # ... create helper for sqlite
    $self->helper(
        sqlite => sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2db ) }
    );

    # ... check for table existance
    my $db = $self->sqlite->db;

    if ( ! @{$db->tables} ) {
        my @SQLITE_INIT_SQLs = (
"CREATE TABLE logs (lhost varchar(64), lfile varchar(255), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, lsize NUMERIC, log TEXT);",
"CREATE INDEX i_logs ON logs (lhost, lfile, ltime);",
        );
        for my $sql (@SQLITE_INIT_SQLs) {
            my $sth = $db->dbh()->prepare($sql);
            $sth->execute() || die "$!";
            say $sql;
        }
    }

    # Router
    my $r = $self->routes;

    # MAIN Route
    $r->get('/' )
      ->to( controller => 'initial', action => 'welcome');
    
    # API
    $r->get('/servers/')
      ->to( controller => 'initial', action => 'servers');

    # Run log file listener thread
    # run_log_file_listener();
}

1;
