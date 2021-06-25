use warnings;
use strict;
use feature 'say';
use Data::Dumper;

my $test_key = 'sdafsdfasdasdfsf';
my %test_hm = ( $test_key => { status => 'run' } );
my $test_v = $test_hm{$test_key} //= { status => 'init' };

say Dumper %test_hm;
say '============';
say Dumper $test_v;


my @array = qw(red blue green);
my @array2 = qw(green);

say "treu" if @array ~~ @array2;