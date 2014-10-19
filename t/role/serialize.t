use Test::More;
use strict; use warnings FATAL => 'all';

{ package My::Hash;
  use strict; use warnings;
  sub new { bless +{@_[1..$#_]}, $_[0] }
  sub TO_JSON { +{ %{ $_[0] } } }
  { no warnings 'once'; *TO_ZPL = *TO_JSON; }
}

{ package My::Serial;
  use strict; use warnings;
  use Role::Tiny::With;
  with 'IRC::Indexer::Role::Serialize';
}

my $obj = My::Hash->new(
  foo => 1,
  bar => 2,
);

my $json = My::Serial->serialize($obj);
my $hash = My::Serial->deserialize($json);
is_deeply $hash, +{ %$obj }, 'roundtripped JSON ok';

done_testing
