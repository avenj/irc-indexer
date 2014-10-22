package IRC::Indexer::Conf;

use strictures 1;

use Carp;
use Scalar::Util 'reftype';

use List::Objects::WithUtils ();
require List::Objects::WithUtils::Hash;
require List::Objects::WithUtils::Array;
use Path::Tiny ();
use Text::ZPL ();

use parent 'List::Objects::WithUtils::Hash::Inflated';

sub new_from_file {
  my ($class, $file) = @_;
  my $zpl = Path::Tiny::path($file)->slurp;
  my $ref = Text::ZPL::decode_zpl($zpl);
  _coerce($ref);
  $class->new(%$ref)
}

sub _coerce {
  ref $_[0] eq 'HASH' ? 
    $_[0] = List::Objects::WithUtils::Hash::Inflated->new(
      map {; _coerce($_) } %{ $_[0] }
    )
  : ref $_[0] eq 'ARRAY' ?
    $_[0] = List::Objects::WithUtils::Array->new(
      map {; _coerce($_) } @{ $_[0] }
    )
  : $_[0]
}

1;
