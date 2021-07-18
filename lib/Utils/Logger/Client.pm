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
my $wdir    = abs_path('.');     # Work directory is current catalog
my $wext    = "log";
my $wfiles  = "$wdir/*.$wext";

#   Default settings when options not specified
my $defaultPort = 9875;
my $listen      = 0;             # Port to listen on

my $defaultReopen = 15;
my $reopenTime    = $defaultReopen * 60;    # How often to re-open files

my $port   = $defaultPort;                  # Port to echo to
my $echoes = 0;                             # Number of echo destinations

#   Internal debugging flags
my $verbose            = 0;    # Print debug output if true
my $progress           = 0;    # Show progress if nonzero
my $tryConver2Hostname = 0;    # Try to convert IP address to hostname

my $mhours     = 12;           # Monitor files that modified for last hours
my $lineWrap   = 76;           # Wrap lines at this column
my $lineChop   = 75;           # Trim lines at this column
my $lineBreak1 = '[,&]';       # Line break first pass candidates
my $lineBreak2 = '[/+]';       # Line break second pass candidates

my %sizes;                     # Sizes of files we're following
my %handles;                   # File handles for file we're following
my $utime = 0;

#   Test flat, just for testing
my $test_flag = 0;             # Just for testing monitoting functionality

#   Definitions for network access
my @destinations;                       # Sockets to echo logs to destination hosts
my @destinations_hosts;                 # Sockets to echo logs to destination hosts
my $defaultEchoHost = '172.30.19.243';  # Default host to echo
my @files = ();

#   To detect termination
my $ctrl_c = 0;                # CTL+C watcher

#   Get current user
my $cuser = getlogin || getpwuid($<) || 'UNKNOWN_USER';

#  Main part to test & run from command line
main() if not caller();

sub main {
    parseArgs();                  # Initialize command line args
    $wfiles = "$wdir/*.$wext";    # refresh wfiles

    $SIG{INT} = $SIG{TERM} = sub {
        print "-=Stop signal catched!=-\n";
        $ctrl_c = 1;
    };

    @files = grep { ( $mhours / 24 ) > -M $_ } glob($wfiles);
    foreach (@ARGV) {
        if ( -e $_ ) {
            push @files, abs_path($_);
        }
        else {
            print "          WARNING: $_ not exist!\n";
        }
    }

    print getInfo();

    if ($test_flag) {
        my ( $total_files, $next_file ) = ( ( $#files + 1 ), 0 );
        foreach my $i (@files) {
            $next_file++;
            qx/echo "\n-=TEST MESSAGE $next_file from $total_files=-" >> $i/;
        }
        exit(0);
    }

    if ( !@files ) {
        print "          ERROR: No files to monitor!\n";
        exit(0);
    }

    addEchoHost($defaultEchoHost, $port);

    runClient( \&defaultClientDeliver );
}

sub testPrint {
    my $message = shift || "No message";
    print "testPrint: $message";
}

sub runClient {
    my $sleepTime = 1;    # Sleep time between poll of files

    while ( 1 && !$ctrl_c ) {

        #   If $reopenTime has elapsed since the last refresh, flag a
        #   reopen required.  Reopening allows us to track files which
        #   are automatically cycled with the previous file being
        #   renamed.

        my $reopen =
          ( $reopenTime > 0 ) && ( ( time() - $utime ) >= $reopenTime );

        foreach my $i (@files) {
            if ( $utime != 0 ) {
                my $s = -s $i;
                if ($progress) {
                    print("++++ $$ Checking file $i, size $s\n");
                }
                my $t;
                if ( defined $s ) {
                    if ( $sizes{$i} < $s ) {
                        if ($progress) {
                            printf( "++++ $$ Reading %d bytes from file $i\n",
                                $s - $sizes{$i} );
                        }
                        my $nread = read( $handles{$i}, $t, $s - $sizes{$i} );

                        #   The following if block merits a little
                        #   explanation.  Since items are appended
                        #   to the log file by another independent
                        #   process, it is possible (albeit unlikely)
                        #   that when we go to read the file the
                        #   other process may not have finished writing
                        #   the log item.  In this case we'll receive a
                        #   partial item, which may not be terminated
                        #   by a new line character.  Such an item could
                        #   mess up our output and confuse the code which
                        #   splits blocks we read into lines.  Since this
                        #   happens so rarely, and should fix itself
                        #   by the next time we poll for updates, we
                        #   take the easy way out and just skip the file
                        #   on this poll, counting on a complete read the
                        #   next time.  It would be more general to
                        #   process any complete lines in the block
                        #   and advance the pointer to the end of
                        #   the last complete line, but for the sake
                        #   of simplicity, we just re-seek the file
                        #   to the start of this read so it's re-read on
                        #   the next poll.

                        if ( !( $t =~ m/.*\n$/ ) ) {
                            seek( $handles{$i}, $sizes{$i}, 0 );
                            if ($progress) {
                                print(
"*** Setting up to reread $i starting at $sizes{$i}\n"
                                );
                            }
                        }
                        else {
                            $sizes{$i} = $s;

                            #   Print locally and echo to specified hosts
                            deliver( "$i: " . $t );
                        }
                    }
                }
            }

            #   If it's time to reopen the files, do it for this one

            if ($reopen) {
                reopenFile($i);
            }
        }
        if ($reopen) {
            $utime = time();
        }
        if ($progress) {
            printf("++++ $$ Done scanning files.\n");
        }
        if ($progress) {
            print("++++ $$ Sleeping\n");
        }
        sleep($sleepTime);
        if ($progress) {
            print("++++ $$ Done sleeping\n");
        }
    }

}

sub reopenFile {
    my $i = $_[0];
    my $s;

    if ($progress) {
        printf("++++ $$ Closing and reopening file $i.\n");
    }
    if ( $utime != 0 ) {
        close($i);
    }
    if ( open( $handles{$i}, "<$i" ) ) {

        #   *** Check if inode of old file is same as new file.  If not,
        #       start reading at zero, not the last seek address.  Note
        #       that reading should be line by line so as not to blow the
        #       65536 MTU of the socket if we're echoing.
        $s = -s $handles{$i};
        $sizes{$i} = $s;
        seek( $handles{$i}, $s, 0 );
        if ($progress) {
            print("** Opened $i, size $s\n");
        }
    }
    else {
        die("** Warning: cannot open file $i: $!\n");
    }
}

sub printWrap {
    my ($s) = $_[0];
    my ( $l, $sep, $rem, $ter, $lwrap );

    #   Pick the input apart line by line and reformat each line,
    #   if necessary, so as not to exceed the maximum line length.
    #   Because we may be running as a subprocess, the wrapping
    #   of each line assembled a string containing all the resulting
    #   lines, which can be written by an atomic I/O, guaranteeing
    #   portions of different lines won't be interleaved due to
    #   switching among multiple processes.

    while ( length($s) > 0 ) {
        if ( ( $s =~ s/(.*\n)// ) != 1 ) {    #TODO: I don't undestand this 'if'
            my $aax = $_[0];
            print("printWrap arg = |$aax|\n");
            print("printWrap s = |$s|\n");
            my $aal = length($s);
            print("printWrap length(s) = $aal\n");
            die("Error splitting lines.");
        }
        $l = $1;

        $sep   = '';
        $lwrap = '';
        if ( ( $lineChop > 0 ) && ( length($l) > $lineChop ) ) {
            $l = substr( $l, 0, $lineChop );
            if ( $l !~ m/\n$/ ) {
                $l .= "\n";
            }
        }
        if ( $lineWrap > 1 ) {
            while ( length($l) > $lineWrap ) {
                if (   ( $l =~ s/(^.{1,$lineWrap})(\s)//o )
                    || ( $l =~ s/(^.{1,$lineWrap})($lineBreak1)//o )
                    || ( $l =~ s/(^.{1,$lineWrap})($lineBreak2)//o ) )
                {
                    $rem = $1;
                    $ter = $2;
                    if ( $ter =~ m/\s+/ ) {
                        $ter = '';
                    }
                    $lwrap .= "$sep$rem$ter\n";
                    $l =~ s/^\s*//;
                    $sep = "        ";
                }
                else {
                    last;
                }
            }
        }
        print("$lwrap$sep$l");
    }
}

sub messageCleaner {
    my ($s) = $_[0];

    #   Change any control or undefined ISO characters into spaces
    #   lest they screw up terminal modes, etc.  We have to leave
    #   end of line characters intact so the line breaking
    #   code will work.
    $s =~ s/[\000-\011\013-\014\016-\037\200-\240]/ /g;
    return $s;
}

sub deliver {
    my $s = messageCleaner( $_[0] );

    print( "Log message length: " . length($s) . " ... " );
    print("-===-\n$s\n-===-") if $verbose;

    #   If we're echoing to one or more other hosts,
    #   send a copy of the information to each.

    if (@destinations) {
        foreach my $h (@destinations) {
            $h->send("$cuser:$s");
        }
        print "sent to (";
        print @destinations_hosts;
        print "), PORT: $port\n";
    }
    else {
        warn("\n** Warning: no destination defined to send message!");
    }
}

sub helpMe {
    print("Usage: logger.pl [ options ] logfile(s) ...\n");
    print("Version $version -- $reldate.\n");
    print("       Options:\n");
    print(
"             -ccols          Chop lines at cols columns, 0 = no chop.\n"
    );
    print(
"             -ehostname      Echo to named host.  Multiple -e options\n"
    );
    print(
"             -vlevel         Verbose: generate debug output.\n");
    print(
"             -lport          Listen for echo on port (default $defaultPort),\n"
    );
    print(
        "             -Dwdir          Monitor file(s) in 'wdir' directory.\n");
    print(
"             -Hhours         Monitor for files modified in last 'hours' (default $mhours).\n"
    );
    print(
"             -wcols          Wrap lines at cols columns, 0 = no wrap.\n"
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
    $result .= "             MODE: CLIENT\n";
    $result .= "            PROTO: UDP\n";
    $result .= "             PORT: $port\n";
    $result .= " FILES UPDATEs IN: $mhours hours\n";
    $result .= "        DIRECTORY: $wdir\n";
    $result .= "        EXTENSION: $wext\n";
    $result .= "            MASKS: $wfiles\n";
    $result .= "       MONITORING: " . ( $#files + 1 ) . " FILES\n";
    map { $result .= qx/ls -lh $_/ } @files;
    return $result;
}

sub parseArgs {

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

            #   -ccols              -- Chop lines at cols columns, 0 = no chop

            if ( $opt eq 'c' ) {
                if ( $arg =~ m/^\d+$/ && $arg >= 0 ) {
                    $lineChop = $arg;
                    if ( $lineChop == 0 ) {
                        $lineChop = 1 << 31;
                    }
                }
                else {
                    die("Invalid chop length '$arg' in -c option.\n");
                }

                #   -Dwdir             - Work directory for monitor log files

            }
            elsif ( $opt eq 'D' ) {
                if ( $arg =~ m/^\W+$/ && -d $arg ) {
                    $wdir = abs_path($arg);
                }

                #   -ehostname          --  Echo to hostname

            }
            elsif ( $opt eq 'e' ) {
                addEchoHost( $arg, $port);
                # my $esock = IO::Socket::INET->new(
                #     PeerHost => $arg,
                #     PeerPort => $port,
                #     Type     => SOCK_DGRAM,
                #     Proto    => 'udp'
                # ) || die("Cannot create echo socket to $arg: $@");

                # push( @destinations,       $esock );
                # push( @destinations_hosts, $arg );

                #   -lport              -- Listen for echo on given port

            }
            elsif ( $opt eq 'l' ) {
                if ( length($arg) > 0 ) {
                    if ( $arg =~ m/^\d+$/ ) {
                        $listen = $arg;
                    }
                    else {
                        die("Invalid port number '$arg' in -l option.\n");
                    }
                }
                else {
                    $listen = $defaultPort;
                }

            }
            elsif ( $opt eq 'H' ) {
                if ( $arg =~ m/^\d+$/ ) {
                    $mhours = $arg;
                }
                else {
                    die("Invalid hours '$arg' in -Hhours option.\n");
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

              #   -wcols              -- Wrap lines at cols columns, 0 = no wrap

            }
            elsif ( $opt eq 'w' ) {
                if ( $arg =~ m/^\d+$/ && $arg >= 0 ) {
                    $lineWrap = $arg;
                    if ( $lineWrap == 0 ) {
                        $lineWrap = 1 << 31;
                    }
                }
                else {
                    die("Invalid wrap length '$arg' in -w option.\n");
                }

#    -T                  -- Test flag, send message to monitoring files and exit

            }
            elsif ( $opt eq 'T' ) {
                $test_flag = 1;
            }
            elsif ( $opt eq 'c' ) {
                if ( $arg =~ m/^\d+$/ && $arg >= 0 ) {
                    $lineChop = $arg;
                    if ( $lineChop == 0 ) {
                        $lineChop = 1 << 31;
                    }
                }
                else {
                    die("Invalid chop length '$arg' in -c option.\n");
                }
            }
        }
    }

}

sub addEchoHost {
    my ($rHost,$rPort) = @_;

    print "Echo to (rHost:rPort): ($rHost:$rPort)\n";

    my $esock = IO::Socket::INET->new(
        PeerHost => $rHost,
        PeerPort => $rPort,
        Type     => SOCK_DGRAM,
        Proto    => 'udp'
    ) || die("Cannot create echo socket to $rHost: $@");

    push( @destinations,       $esock );
    push( @destinations_hosts, $rHost );            
}

1;
