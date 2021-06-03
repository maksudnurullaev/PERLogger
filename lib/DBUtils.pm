package DBUtils;

use Mojo::Base -strict;
use Mojo::Home;

use Data::Dumper;

use Utils;
use SQL::Abstract::Pg;

# SQLite
my $sqlite;

sub set_sqlite {
    $sqlite = $_[0] if $_[0];
}

sub get_init_sqls {
    return (
"CREATE TABLE logs (lhost varchar(64), lhost_md5 varchar(4), luser varchar(16), lfile varchar(255), lfile_md5 varchar(4), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, lsize NUMERIC, log TEXT);",
"CREATE INDEX i_logs ON logs (lhost, lhost_md5, luser, lfile, lfile_md5, ltime);",
    );
}

sub parse_it {
    Utils::print_error "Database not initilized!" and return
      if !defined($sqlite);

    my $rowLog = $_[0];

    my ( $lhost, $user, $lfile, $lsize, $log );
    my @parts = split /\:/, $rowLog, 4;

    # check for HOST(1) : LOGFILE(2) : TEXT(3)
    if ( scalar(@parts) < 4 ) {
        Utils::print_warn "Unknown format of log: " . $rowLog;
        return;
    }

    # 1. get LHOST part
    if ( $parts[0] =~ /\((.*)\)/ ) {
        $lhost = $1;
    }
    else {
        $lhost = "UNKNOWN";
    }

    # 2. get remove USER name, who echo message
    $parts[1] =~ s/^\s+|\s+$//g;
    $user = $parts[1];

    # 3. get LFILE part
    $parts[2] =~ s/^\s+|\s+$//g;
    $lfile = $parts[2];

    # 4. get LOG text part
    $parts[3] =~ s/^\s+|\s+$//g;
    $log = $parts[3];

    my $db = $sqlite->db;
    if ($db) {
        $db->insert(
            logs => {
                lhost     => $lhost,
                lhost_md5 => Utils::md5( $lhost, 0, 4 ),
                luser     => $user,
                lfile     => $lfile,
                lfile_md5 => Utils::md5( $lfile, 0, 4 ),
                log       => $log
            }
        );
        $lfile =~ /[^\/]+$/;
        Utils::print_info( "Log from $& inserted, size: " . length($log) );
    }
    else {
        Utils::print_error "Database not initilized!";
    }
}

sub get_servers_with_stats {
    Utils::print_error "Database not initilized!" and return
      if !defined($sqlite);

    my $db = $sqlite->db;
    my $results =
      $db->query(
        'select count(*) as count, lhost, lhost_md5 from logs group by lhost');

    return $results->hashes->TO_JSON;
}

sub get_servers_and_log_files {
    Utils::print_error "Database not initilized!" and return
      if !defined($sqlite);

    my $db = $sqlite->db;
    my $sql_string =
      'select distinct lhost, lhost_md5, luser, lfile, lfile_md5 from logs';
    $sql_string .= "  where lhost = '$_[0]'" if $_[0];
    Utils::print_info( "SQL to select server and log files: " . $sql_string );

    my $results = $db->query($sql_string);

    return Utils::hashesGroupBy( $results->hashes, 'lhost', 'luser');
}

sub get_logs {
    Utils::print_error "Database not initilized!" and return
      if !defined($sqlite);

    my $sql = $sqlite->abstract(
        SQL::Abstract::Pg->new( name_sep => '.', quote_char => '"' ) );

    my $result = $sql->db->select(
        'logs',
        [ 'log', 'OID', 'ltime' ],

        # [ 'lhost', 'lfile', \q{ length(log) as len_log}, 'OID', 'ltime' ],
        $_[0], { limit => 25, order_by => { -desc => 'ltime' } }
    );

    # while ( my $next = $results->hash ) {
    #     say $next->{ltime} . ' - ' . $next->{rowid} ;
    # }
    return $result->hashes;
}

1;
