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
  $self->{Network} = {
    Servers => {
     ## ServerName => {
     ##   MOTD => [],
     ## }
    },
    
    OperCount   => undef,
    GlobalUsers => undef,
    ListChans   => [],
    HashChans   => {},
    
    ConnectedAt => undef,
    FinishedAt  => undef,
  };
  return $self
}

sub dump {
  ## FIXME
}

sub add_server {
  my ($self, $info) = @_;
  ## given a Info::Server object, merge to this Network
  return unless $info and ref $info;
  my $name = $info->server;
  my $motd = $info->motd;  
  
  ## keyed on reported server name
  ## will "break"-ish on dumb nets announcing dumb names:
  my $network = $self->{Network};
  my $servers = $network->{Servers};
  $servers->{$name}->{MOTD} = $motd;
  
  ## these can all be overriden network-wide:
  $network->{GlobalUsers} = $info->users;
  $network->{OperCount}   = $info->opers;
  $network->{ListChans}   = $info->channels;
  $network->{HashChans}   = $info->chanhash;
  $network->{ConnectedAt} = $info->connectedat;
  $network->{FinishedAt}  = $info->finishedat;
}

1;
__END__
