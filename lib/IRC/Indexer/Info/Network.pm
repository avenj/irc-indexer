package IRC::Indexer::Info::Network;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

sub new {
  my $self = {},
  my $class = shift;
  bless $self, $class;
  $self->{Network} = {};
  return $self
}

sub dump {
  ## FIXME
}

sub add_server {
  my ($self, $info) = @_;
  ## given a Info::Server object, merge to this Network
  return unless $info and ref $info;
  my $network = $info->network;
  
  ## FIXME
}

1;
__END__
