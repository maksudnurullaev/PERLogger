package EnDeCrypt;

use Mojo::Base -strict;
use Crypt::Simple;


sub encryptMe {
    return encrypt(@_);
}

sub decryptMe {
    return decrypt(@_);
}

1;
