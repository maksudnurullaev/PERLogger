#! /usr/bin/perl

package Logger;

#
#                          Log Watcher (Logger)
#
#                  by Makhsud Nurullaev -- Feb, 2021
#                  Modified version of John Walker's
#           "Log File Watcher" script(https://www.fourmilab.ch/webtools/logtail/)

use strict;
use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname basename );
use Time::Local;
use Socket;
use IO::Socket;
use Data::Dumper;

my $version = '0.0.1b';
my $reldate = '2021 Feb 23';

#   Default settings when options not specified
my $defaultPort = 9875;
my $listen      = $defaultPort;    # Port to listen on

#   Internal debugging flags
my $verbose            = 0;       # Print debug output if true
my $progress           = 0;       # Show progress if nonzero
my $tryConver2Hostname = 0;       # Try to convert IP address to hostname

my $utime = 0;

#   To detect termination
my $ctrl_c = 0;                   # CTL+C watcher

#  Main part to test & run from command line
main() if not caller();

sub main {
    parseArgs();                  # Initialize command line args

    $SIG{INT} = $SIG{TERM} = sub {
        print "-=Stop signal catched!=-\n";
        $ctrl_c = 1;
    };

    print getInfo();

    runServer( \&defaultServerDeliver );
}

sub testPrint {
    my $message = shift || "No message";
    print "testPrint: $message";
}

sub stopServer { $ctrl_c = 1; }

sub runServer {
    my $messageHandler = shift || \&defaultServerDeliver;
    my $sock;    # Socket to listen for entries from other hosts
    $listen = $defaultPort if !$listen;

    #   If we're to receive messages from other hosts, create
    #   the inbound socket and bind it to the specified port.

    print "Create inboud socket...\n" if $progress;
    foreach my $dest ( "::", "0.0.0.0" ) {
        if (
            $sock = IO::Socket::INET->new(
                LocalHost => $dest,
                LocalPort => $listen,
                Type      => SOCK_DGRAM,
                Proto     => 'udp'
            )
          )
        {
            last;
        }
    }
    if ( !$sock ) {
        die("Error creating listen socket: $@");
    }

    my ( $name, $msg );
    print "      LISTEN PORT: $listen\n" if $progress;
    while ( $listen && $sock->recv( $msg, 65535 ) && !$ctrl_c ) {
        my ( $port, $ipaddr ) = sockaddr_in( $sock->peername );
        my $hostname .= "(" . inet_ntoa($ipaddr) . ")";
        if ($tryConver2Hostname) {
            $hostname = gethostbyaddr( $ipaddr, AF_INET );
            if ( $hostname and $hostname !~ m/^\d+\./ && !$verbose ) {
                $hostname =~ s/\..*$//;
            }
        }

        $msg =~ s/\n$//;

        #   Print the message locally, but don't echo
        $messageHandler->( "$hostname: $msg", 0 );
    }
}

sub deliver {
    print( "$_[0]\n");
}

sub helpMe {
    print("Usage: logger.pl [ options ] logfile(s) ...\n");
    print("Version $version -- $reldate.\n");
    print("       Options:\n");
    print("             -vlevel         Verbose: generate debug output.\n");
    print(
"             -lport          Listen for echo on port (default $defaultPort),\n"
    );
    print(
"             -T              Just send test messages to monitoring files.\n"
    );
    print("Report bugs to maksud.nurullaev\@gmail.com\n");
    exit(0);
}

sub getInfo {
    my $result = "     PERL VERSION: $]\n";
    $result .= "   SCRIPT VERSION: $version\n";
    $result .= "             MODE: SERVER\n";
    return $result;
}

sub parseArgs {

    helpMe and exit(0) until @ARGV;

    #   Process options on command line
    for ( my $i = 0 ; $i <= $#ARGV ; $i++ ) {
        my ( $o, $arg, $opt );

        if ( $ARGV[$i] =~ m/^-/ ) {
            $o = $ARGV[$i];
            splice( @ARGV, $i, 1 );
            $i--;
            if ( length($o) == 1 ) {
                last;
            }
            $opt = substr( $o, 1, 1 );
            $arg = substr( $o, 2 );

            #   -lport              -- Listen for echo on given port

            if ( $opt eq 'l' ) {
                if ( length($arg) > 0 ) {
                    if ( $arg =~ m/^\d+$/ ) {
                        $listen = $arg;
                    }
                    else {
                        die("Invalid port number '$arg' in -l option.\n");
                    }
                }

                #   -?                  -- Print help
            }
            elsif ( $opt eq '?' ) {
                helpMe;

                #   -vlevel             -- Verbose: generate debug output
            }
            elsif ( $opt eq 'v' ) {
                $verbose = 1;
                if ( length($arg) > 0 ) {
                    if ( $arg =~ m/^\d+$/ && $arg >= 0 ) {
                        $progress = $arg;
                    }
                    else {
                        die("Invalid verbosity level '$arg' in -v option.\n");
                    }
                }
            }
        }
    }

}

1;
