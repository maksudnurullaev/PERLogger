package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

use Term::ANSIColor;
use Data::Dumper;

use Mojo::SQLite;
use Mojo::Home;

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
        _Prefix( "ERROR", "red",
"Not defined location for SQLite database file (dir4db) in configuration file"
        );
        exit(1);
    }

    # Check & Configure database
    my $home = Mojo::Home->new;
    $home->detect;
    my $path2db = $home->rel_file( $config->{dir4db} );
    my $dir     = $path2db->dirname();

    # ... check database directory existance
    if ( !-d $path2db->dirname ) {
        _Prefix( "WARNING", "yellow",
            "$path2db not exitst, trying to create new one..." );
        make_path $dir
          or die "$!: Failed to create path: " . $dir;
    }

    # ... create helper for sqlite
    $self->helper(
        sqlite => sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2db ) }
    );

    # ... check for table existance
    my $db = $self->sqlite->db;

    if ( ! @{$db->tables} ) {
        my @SQLITE_INIT_SQLs = (
"CREATE TABLE logs (server varchar(64), logfile varchar(255), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, log TEXT );",
"CREATE INDEX i_logs ON logs (server, logfile, ltime);",
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
}

sub _Prefix {
    my ( $prefix, $color, $msg ) = @_;
    if ( $^O =~ /win/i ) {
        print sprintf( "[%s]: ", $prefix );
    }
    else {
        print colored( sprintf( "%s: ", $prefix ), $color );
    }
    say $msg;
}

1;
