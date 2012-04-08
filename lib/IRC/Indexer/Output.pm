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

sub dump {
  my ($self) = @_;
  return $self->{Output}
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

=head1 SYNOPSIS

  use IRC::Indexer::Output::JSON;
  # or: use IRC::Indexer::Output::YAML;
  # or: use IRC::Indexer::Output::Dumper;
  
  ## Convert trawler output into JSON, for example:
  my $output = IRC::Indexer::Output::JSON->new(
    Input => $trawler->dump,
  );
  
  ## Get output as a scalar:
  print $output->dump;
  
  ## Write output to file:
  $output->write($path);

=head1 DESCRIPTION

The IRC::Indexer::Output subclasses can convert 
L<IRC::Indexer::Bot::Trawl> hashes into portable data formats.

B<You wouldn't normally use this module directly> unless you are writing 
an output subclass; instead, you would use a subclass for a particular 
format, such as L<IRC::Indexer::Output::JSON>.

=head1 API

When writing an output subclass, you will need to override the methods 
B<dump()> and B<write()> to set a proper Output scalar:

  our @ISA = qw/IRC::Indexer::Output/;
  
  sub dump {
    my ($self) = @_;
    my $input = $self->{Input};
    ## Serialize the $input hashref any way you like:
    $self->{Output} = frobulate_my_input($input);
    $self->SUPER::dump();
  }
  
  sub write {
    my ($self, $path) = @_;
    my $input = $self->{Input};
    $self->{Output} = frobulate_my_input($input);
    $self->SUPER::write($path);
  }

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
