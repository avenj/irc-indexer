package IRC::Indexer::Conf::Server;

use strictures 1;

use List::Objects::Types -types;
use Types::Standard -types;

use Moo; use MooX::late;

has enabled => (
  required  => 1,
  is        => 'ro',
  isa       => Bool,
);

has listen  => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);

has max_local_workers => (
  required  => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 5 },
);

has enable_peers => (
  required  => 1,
  is        => 'ro',
  isa       => Bool,
);

has peer_timeout => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 320 },
);

has peer_servers => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayObj,
  coerce    => 1,
  builder   => sub { [] },
);

1;
