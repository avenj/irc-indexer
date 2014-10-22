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

=pod

=head1 NAME

IRC::Indexer::Conf - Inflated ZPL configs for IRC::Indexer

=head1 SYNOPSIS

  use IRC::Indexer::Conf;

  my $cfg = IRC::Indexer::Conf->new_from_file(
    '/my/config.zpl'
  );

  # Hashes are List::Objects::WithUtils::Hash::Inflated objects:
  my $bar = $cfg->foo->bar;

  # Lists are List::Objects::WithUtils::Array objects:
  my @things = $cfg->things->all;

=head1 DESCRIPTION

Reads and inflates C<ZPL> format configuration files via L<Text::ZPL> and
L<List::Objects::WithUtils>.

=head2 new_from_file

Takes a path to a C<ZPL>-format configuration file and returns a
L<List::Objects::WithUtils::Hash::Inflated>.

The hash is deeply coerced; hashes are inflated as stated above, and lists
become L<List::Objects::WithUtils::Array> objects.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>


=cut
