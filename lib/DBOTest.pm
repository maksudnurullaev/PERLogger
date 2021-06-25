package DBOTest; {

=encoding utf8

=head1 NAME

   Just for testing proposes

=cut

use 5.012000;
use strict;
use warnings;
use utf8;
use parent 'DBO';

sub new {
    my $class = shift;
    my $mojo  = shift;
    my $file_path = $mojo->app->home->rel_file("DATA/test.db");
    my $self = { mojo => $mojo, 
                 file => $file_path };
    bless $self, $class;
    return($self);
};

};

1;

__END__

=head1 AUTHOR

 M.Nurullaev <maksud.nurullaev@gmail.com>

=cut

