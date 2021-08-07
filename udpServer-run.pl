package Server;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Mojo::SQLite;
use Mojo::Log;

use Utils;
use Utils::DBLogs;
use Utils::Logger::Server;

use CPAN::Meta::YAML;

use Data::Dumper;

use File::Lockfile;

# reading a config file
my ( $fh, $yaml_text, $yaml );

open $fh, "<:utf8", "p_e_r_logger.yml";
$yaml_text = do { local $/; <$fh> };
$yaml      = CPAN::Meta::YAML->read_string($yaml_text)
  or die CPAN::Meta::YAML->errstr;

# check for already runnung
my $lockfile = File::Lockfile->new( $yaml->[0]->{'updServerPIDFile'},
    ( "$FindBin::Bin/" . $yaml->[0]->{'updServerPIDFilePath'} ) );
    
# ... check
if ( my $pid = $lockfile->check ) {
        print "UDP server already running with PID: $pid\n";
        exit;
}

# ... write lockfile
$lockfile->write;

# setup log
my $log = Mojo::Log->new(path => ("$FindBin::Bin/" . $yaml->[0]->{'path4Logging'}));
Utils::set_logger $log => "UDPServer";

# setup db
my $path2LogsDb = "$FindBin::Bin/" . $yaml->[0]->{'path2LogsDb'};
my $sql         = Mojo::SQLite->new( 'sqlite:' . $path2LogsDb );

DBLogs::setup_sqlite $sql;
Server::runServer( \&DBLogs::parse_it );
