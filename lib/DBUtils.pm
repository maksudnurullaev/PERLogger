package DBUtils;

use Mojo::Base -strict;
use Mojo::Home;

use Data::Dumper;

use Utils;

# DB
my $db;

sub set_db{
    $db = $_[0] if $_[0];
};

sub get_init_sqls{
    return (
            "CREATE TABLE logs (lhost varchar(64), lfile varchar(255), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, lsize NUMERIC, log TEXT);",
            "CREATE INDEX i_logs ON logs (lhost, lfile, ltime);",
            );
};

sub parse_it{
    my $rowLog = $_[0];

    my($lhost,$lfile,$lsize, $log);
    my @parts = split /\:/, $rowLog, 3;

    # check for HOST(1) : LOGFILE(2) : TEXT(3) 
    if (scalar(@parts) < 3) {
        Utils::print_warn "Unknown format of log: " . $rowLog;
        return;
    } 

    # 1. get LHOST part
    if ( $parts[0] =~ /\((.*)\)/ ) {
        $lhost = $1;
    } else {
        $lhost = "UNKNOWN";
    }

    # 2. get LFILE part
    $parts[1] =~ s/^\s+|\s+$//g;
    $lfile = $parts[1];

    # 3. get LOG text part
    $parts[2] =~ s/^\s+|\s+$//g;
    $log = $parts[2];

    if( $db ){
        $db->insert( logs => {
            lhost => $lhost,
            lfile => $lfile,
            log   => $log
        });
        Utils::print_info("Log inserted, size: " . length($log) );
    } else {
        Utils::print_error "Database not initilized!";
    }
};

sub get_server_logs{
    Utils::print_error "Database not initilized!" and return if ! defined($db);

    my $results = $db->query('select count(*) as count, lhost from logs group by lhost');

    return $results->hashes->TO_JSON;
};

1;
