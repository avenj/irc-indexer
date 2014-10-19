package IRC::Indexer::Role::Serialize;

use Carp;
use strictures 1;

use JSON::MaybeXS;
our $Json = JSON::MaybeXS->new(
  allow_nonref    => 1,
  convert_blessed => 1,
);

use Role::Tiny;

sub serialize {
  $Json->encode($_[1])
}

sub deserialize {
  $Json->decode($_[1])
}

1;
