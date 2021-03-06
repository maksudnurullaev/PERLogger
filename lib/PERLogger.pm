package PERLogger;
use Mojo::Base 'Mojolicious', -signatures;
use Mojolicious::Routes;

use Term::ANSIColor;

use Mojo::SQLite;
use Mojo::Home;

# This method will run once at server start
sub startup ($self) {

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig');

    my $home = Mojo::Home->new;

    # Configure the application
    $self->secrets( $config->{secrets} );

    # Configure database
    if ( !defined( $config->{dir4db} ) ) {
        _Prefix( "ERROR", "red",
"Not defined location for SQLite database file (dir4db) in configuration file"
        );
        exit(1);
    }
    else {
        my $home = Mojo::Home->new;
        $home->detect;
        my $path2db = $home->rel_file( $config->{dir4db} );

        if ( !-d $path2db->dirname ) {
            _Prefix( "WARNING", "yellow",
                "$path2db not exitst, trying to create new one..." );
            make_path $path2db->dirname
              or die "Failed to create path: " . $path2db->dirname;
        }

        $self->helper( sqlite =>
              sub { state $sql = Mojo::SQLite->new( 'sqlite:' . $path2db ) } );

        if ( !-e $path2db ) {
            my @SQLITE_INIT_SQLs = (
"CREATE TABLE IF NOT EXIST logs (server varchar(32), logfile varchar(255), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, log TEXT );",
"CREATE INDEX IF NOT EXIST i_logs ON logs (server, logfile, ltime);",
            );
            for my $sql (@SQLITE_INIT_SQLs) {
                my $stmt = $connection->prepare($sql);
                $stmt->execute
                  || die "Error:Db: Could not init database with: $sql";
            }
            $dbh->do('');
            die "Failed to create db file, path: " . $path2db;
        }

        exit(1);
    }

    # Router
    my $r = $self->routes;

    # MAIN Route
    $r->any( [ 'GET', 'POST' ], '/' )
      ->to( controller => 'initial', action => 'welcome', payload => undef );
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