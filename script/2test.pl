use warnings;
use strict;
use feature 'say';
use Data::Dumper;

use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);

use Crypt::Simple;
 
my $data = encrypt("somePassword!");
print $data, "\n";
 
my $same_stuff = decrypt($data);
print "$same_stuff\n";

print decrypt("U+8DuYRGSsGQEIFUdJ8ad1boYOEhEciRXYMfg3CuG0l3sUknhpxDxPcoKsbv4OD5"), "\n";
