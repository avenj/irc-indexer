package IRC::Indexer::Conf::Client;

use strictures 1;

use Types::Standard -types;

use Moo; use MooX::late;

has enabled => (
  required  => 1,
  is        => 'ro',
  isa       => Bool,
);

has server => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);

has timeout => (
  is        => 'ro',
  isa       => Int,
  builder   => sub { 320 },
);

has trawl_list_path => (
  is        => 'ro',
  isa       => Maybe[Str],
  builder   => sub { undef },
);


sub BUILD {
  my ($self) = @_;
  if ($self->enabled && !$self->trawl_list_path) {
    confess "Client enabled but no 'trawl_list_path' specified"
  }
}

1;
