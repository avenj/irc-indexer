package IRC::Indexer::Output;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;

  my %args = @_;
  
  $args{lc $_} = delete $args{$_} for keys %args;
  
  $self->{Input} = $args{input} || croak "No input specified in new" ;

  return $self
}

sub write {
  my ($self, $path) = @_;
  
  unless ($path) {
    croak "write() called but no path specified" ;
  }
  
  my $out;
  unless ($out = $self->{Output}) {
    croak "write() called but no Output to write" ;
  }
  
  open my $fh, '>:encoding(utf8)', $path 
    or croak "open failed in write(): $!";
  print $fh $out;
  close $fh;
}



1;
__END__

=pod

=head1 NAME

IRC::Indexer::Output - Turn trawler output into something useful

=head1 DESCRIPTION

FIXME

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
