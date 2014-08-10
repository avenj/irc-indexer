package IRC::Indexer::Conf::TrawlList;

use strictures 1;

use List::Objects::WithUtils;
use List::Objects::Types -types;

use Types::Path::Tiny;

use JSON::Tiny;


use Moo; use MooX::late;

has trawl_list_path => (
  required  => 1,
  is        => 'ro',
  isa       => AbsFile,
  coerce    => 1,
);

has networks => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayObj,
  coerce    => 1,
  builder   => sub { [] },
);


# trawl list:
# +{
#   $network => +{
#     servers => [
#       "serverA",
#       "serverB",
#       [ "serverC", +{ port => $pt, ... } ],
#       ...
#     ],
#   },
#   ...
# }

sub BUILD {
  my ($self) = @_;
  my $nets = JSON::Tiny->new->decode( $self->trawl_list_path->slurp_utf8 );

  confess "Broken trawl list; expected a HASH but got $nets"
    unless ref $nets eq 'HASH';
  $nets = hash(%$nets);

  for my $netname ($nets->keys->all) {
    my $netitem = $nets->get($netname);
    unless (ref $netitem eq 'HASH') {
      confess
       "Broken trawl list; key '$netname', expected a HASH but got $netitem"
    }
    $netitem = hash(%$netitem);

    my $servlist = $netitem->get('servers');

    # FIXME
  }
}


1;
