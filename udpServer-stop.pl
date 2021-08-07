package Server;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use CPAN::Meta::YAML;
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
        kill 'INT', $pid;
        $lockfile->remove;
        print "UPD server with PID: $pid stopped!\n";
} else {
        print "Running UPD server not found!\n";  
}