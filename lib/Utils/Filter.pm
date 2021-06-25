package Utils::Filter; {

=encoding utf8

=head1 NAME

    Different utilites 

=cut

use 5.012000;
use strict;
use warnings;
use utf8;
use Data::Dumper;

my $DEFAULT_PAGE = 1 ;
my $DEFAULT_PAGESIZE = 5 ;

sub get_default_page{ return($DEFAULT_PAGE); };
sub get_default_pagesize{ return($DEFAULT_PAGESIZE); };

sub get_unique_path{ 
    my ($self,$postfix) = @_; 
    my $result          = $self->param('path') || $self->req->url->path->to_string() ;
    return($postfix ? ($result . $postfix) : $result );
};

sub get_pagesize_path{ my $self = shift; return(get_unique_path($self,'/pagesize')) ; };
sub get_page_path{     my $self = shift; return(get_unique_path($self,'/page')) ; };
sub get_pages_path{    my $self = shift; return(get_unique_path($self,'/pages')) ; };
sub get_filter_path{   my $self = shift; return(get_unique_path($self,'/filter')) ; };

sub pagesize{
    my $self = shift;
    set_pagesize($self, $self->param('payload')) 
        if $self->param('payload') && $self->param('payload') =~/^\d+$/ ; 
    $self->redirect_to($self->param('path')) if $self->param('path') ;
};

sub page{
    my $self = shift;
    set_page($self, $self->param('payload')) 
        if $self->param('payload') && $self->param('payload') =~/^\d+$/ ; 
    $self->redirect_to($self->param('path')) if $self->param('path') ;
};

sub nofilter{
    my $self = shift ;
    delete $self->session->{get_filter_path($self)} ;
    $self->redirect_to($self->param('path')) if $self->param('path') ;
};

sub filter{
    my $self = shift;
    set_filter($self, $self->param('filter')) 
        if $self->param('filter') ; 
    $self->redirect_to($self->param('path')) if $self->param('path') ;
};

sub get_pagesize{
    my $self = shift;
    return($self->session->{get_pagesize_path($self)} || $DEFAULT_PAGESIZE);
};

sub get_page{
    my $self = shift;
    return($self->session->{get_page_path($self)} || $DEFAULT_PAGE);
};

sub get_pages{
    my $self = shift;
    return($self->session->{get_pages_path($self)} || $DEFAULT_PAGE);
};

sub get_filter{
    my $self = shift ;
    return($self->session->{get_filter_path($self)}) ;
};

sub set_pagesize{
    my ($self,$value) = @_ ;
    $self->session->{get_pagesize_path($self)} = $value;
};

sub set_page{
    my ($self,$value) = @_ ;
    $self->session->{get_page_path($self)} = $value;
};

sub set_pages{
    my ($self,$value) = @_ ;
    $self->session->{get_pages_path($self)} = $value;
};

sub set_filter{
    my ($self,$value) = @_ ;
    $self->session->{get_filter_path($self)} = $value;
};

sub setup_pages{
    my ($self,$items_count) = @_;
    my $page       = get_page($self);
    my $pagesize   = get_pagesize($self);
    my $pages      = 1 ;

    if( $pagesize >= $items_count){
        $pages = 1 ;
        $page  = 1 ;
        $pages = 1 ;
    }else {
        my $delta = $items_count % $pagesize; 
        $pages = $delta ?
            (($items_count - $delta)/$pagesize) + 1
            : $items_count/$pagesize ;
        $page = $pages if $pages < $page ;
    }
    set_pages($self,$pages);
    set_page($self,$page);
    return(($page,$pages,$pagesize));
};


# END OF PACKAGE
};

1;

__END__

=head1 AUTHOR

    M.Nurullaev <maksud.nurullaev@gmail.com>

=cut

