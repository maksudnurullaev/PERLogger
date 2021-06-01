use Digest::MD5 qw(md5_hex);

use Mojo::File qw(curfile);
use lib curfile->dirname->sibling('lib')->to_string;

use Utils;
print "Digest is ", md5_hex("foobarbaz"), "\n";
print "Digest is ", substr(md5_hex("foobarbaz"),0,4), "\n";
print "Digest is ", Utils::md5("foobarbaz",0,5), "\n";
