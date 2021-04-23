package DBUtils;

use Mojo::Base -strict;
use Mojo::Home;

use Data::Dumper;

use Utils;

my @SQLITE_INIT_SQLs = (

"CREATE TABLE logs (lhost varchar(64), lfile varchar(255), ltime TIMESTAMP DEFAULT CURRENT_TIMESTAMP, lsize NUMERIC, log TEXT);",
"CREATE INDEX i_logs ON logs (lhost, lfile, ltime);",
        );

sub parse_it{
    my $rowLog = $_[0];

    my($lhost,$lfile,$lsize, $ltext);
    my @parts = split /\:/, $rowLog, 3;

    # check for HOST(1) : LOGFILE(2) : TEXT(3) 
    if (scalar(@parts) < 3) {
        Utils::print_warn "Unknown format of log: " . $rowLog;
        return;
    } else {
        Utils::print_warn "SIZE: " . scalar(@parts);
        print Dumper(@parts);
    }

    # # 1. get HOST part
    # if ( $parts[0] =~ /\((.*)\)/ ) {
    #     $lhost = $1;
    # } else {
    #     $lhost = "UNKNOWN";
    # }

    # Utils::print_warn "lhost: $lhost";
    # Utils::print_warn $_[0];
};

1;
