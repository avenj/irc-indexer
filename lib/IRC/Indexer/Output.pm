package IRC::Indexer::Output;

use 5.10.1;
use Carp 'confess';
use Scalar::Util 'openhandle';

use Moo;

has input => (
  is        => 'ro',
  required  => 1,
  isa       => sub {
    defined $_[0] or confess "input() not defined"
  },
);

has output => (
  is        => 'rw',
  lazy      => 1,
  isa       => sub {
    defined $_[0] or confess "output() not defined"
  },
  default   => sub { '' },
);

sub BUILDARGS {
  my ($class, %args) = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
  +{%args}
}

sub dump {
  my ($self) = @_;
  $self->output
}

sub write {
  my ($self, $path) = @_;
  
  unless ($path) {
    confess "write() called but no path specified" ;
  }
  
  my $out;
  unless ($out = $self->output) {
    confess "write() called but no Output to write" ;
  }

  if ( openhandle($path) ) {
    print $path $out;
  } else {
    open my $fh, '>:encoding(utf8)', $path 
      or confess "open failed in write(): $!";
    print $fh $out;
    close $fh;
  }
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
    input => $trawler->dump,
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

=head1 METHODS

=head2 new

Create an output encoder; the reference to serialize must be specified:

  my $out = IRC::Indexer::Output::JSON->new(
    input => $ref,
  );

=head2 dump

Return the serialized output as a scalar.

  my $json = $out->dump;

=head2 write

Write serialized output to a file path or an opened FH.

  $out->write($path);

Will confess() on error.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
