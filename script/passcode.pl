use Digest::MD5 qw(md5_hex);

use Mojo::File qw(curfile);
use lib curfile->dirname->sibling('lib')->to_string;

use Utils;
print "Digest is ", md5_hex("foobarbaz"), "\n";
print "Digest is ", substr(md5_hex("foobarbaz"),0,4), "\n";
print "Digest is ", Utils::md5("foobarbaz",0,5), "\n";


print "Digest is ", Utils::md5("/uzb-mps/prusers/uzboper/var/tsh/log/MPSRATER_TSHR01016_TSH_uzb-mps_20210604100350.log",0,5), "\n";
print "Digest is ", Utils::md5("/uzb-mps/prusers/uzboper/var/tsh/log/RATER0111_TSHR01011_TSH_uzb-mps-n2_20210306_173414.log",0,5), "\n";

print "Digest is ", Utils::md5("/uzb-mps/prusers/uzboper/var/tsh/log/RATER0111_TSHR01011_TSH_uzb-mps-n2_20210306_173414.log",0,5), "\n";

print "Passcode: " . md5_hex('wwwww') . "\n";