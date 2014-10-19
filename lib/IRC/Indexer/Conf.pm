package IRC::Indexer::Conf;

use strictures 1;

use List::Objects::Types -types;

use Path::Tiny ();
use Text::ZPL ();

use parent 'List::Objects::WithUtils::Hash::Inflated';

sub new_from_file {
  my ($class, $file) = @_;
  my $zpl = Path::Tiny::path($file)->slurp;
  $class->new( %{ Text::ZPL::decode_zpl($zpl) } )
}

1;
