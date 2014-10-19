package IRC::Indexer::Conf;

use strictures 1;

use List::Objects::WithUtils ();
use Path::Tiny ();
use Text::ZPL ();

use parent 'List::Objects::WithUtils::Hash::Inflated';

sub new_from_file {
  my ($class, $file) = @_;
  my $zpl = Path::Tiny::path($file)->slurp;
  my @items = %{ Text::ZPL::decode_zpl($zpl) };
  my @handled;
  while (my ($k, $v) = splice @items, 0, 2) {
    push @handled,
      ref $v eq 'HASH' ? ($k, $class->new(%$v))
        : ref $v eq 'ARRAY' ? ($k, List::Objects::WithUtils::Array->new(@$v))
        : ($k, $v) 
  }
  $class->new(@handled)
}

1;
