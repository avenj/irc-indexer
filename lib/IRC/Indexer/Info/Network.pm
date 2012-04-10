package IRC::Indexer::Info::Network;

use 5.12.1;
use strict;
use warnings;
use Carp;

use Storable qw/dclone/;

use Scalar::Util qw/blessed/;

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
    
    ListLinks  => [],
    LastServer => undef,
    
    ConnectedAt => undef,
    FinishedAt  => undef,
  };
  return $self
}

## Simple read-only accessors:

## Remain compatible with Info::Server interface:
sub info { netinfo(@_) }
sub dump { netinfo(@_) }
sub netinfo {
  my ($self) = @_;
  return $self->{Network}
}

sub servers {
  my ($self) = @_;
  return $self->{Network}->{Servers}
}

sub motd_for {
  my ($self, $server) = @_;
  return unless $server;
  return unless exists $self->{Network}->{Servers}->{$server};
  return $self->{Network}->{Servers}->{$server}->{MOTD} // []
}

sub opers {
  my ($self) = @_;
  return $self->{Network}->{OperCount}
}

sub users {
  my ($self) = @_;
  return $self->{Network}->{GlobalUsers}
}

sub listchans { channels(@_) }
sub channels {
  my ($self) = @_;
  return $self->{Network}->{ListChans}
}

sub hashchans { chanhash(@_) }
sub chanhash {
  my ($self) = @_;
  return $self->{Network}->{HashChans}
}

sub connectedat {
  my ($self) = @_;
  return $self->{Network}->{ConnectedAt}
}

sub finishedat {
  my ($self) = @_;
  return $self->{Network}->{FinishedAt}
}

sub lastserver {
  my ($self) = @_;
  return $self->{Network}->{LastServer}
}

sub add_server {
  my ($self, $info) = @_;
  ## given a Info::Server object (or subclass), merge to this Network
  croak "add_server needs an IRC::Indexer::Info::Server obj"
    unless blessed $info;
  
  ## keyed on reported server name
  ## will "break"-ish on dumb nets announcing dumb names:
  my $network = $self->{Network};
  my $servers = $network->{Servers};

  my $name = $info->server;
  my $motd = $info->motd;  
  $servers->{$name}->{MOTD} = $motd;
  
  ## these can all be overriden network-wide:
  $network->{GlobalUsers} = $info->users;
  $network->{OperCount}   = $info->opers;
  $network->{ListChans}   = $info->channels;
  $network->{HashChans}   = $info->chanhash;
  $network->{ConnectedAt} = $info->connectedat;
  $network->{FinishedAt}  = $info->finishedat;
  $network->{ListLinks}   = $info->links;
  $network->{LastServer}  = $name;
}

1;
__END__

=pod

=head1 NAME

IRC::Indexer::Info::Network - Network information class for IRC::Indexer

=head1 SYNOPSIS

  my $network = IRC::Indexer::Info::Network->new;
  ## Get ::Info::Server object from finished trawl bot:
  my $info_obj  = $trawler->info;
  ## Feed it to add_server:
  $network->add_server( $info_obj );
  ## Get a network info hash:
  my $net_hash = $network->dump;

=head1 DESCRIPTION

This is a simple Network class for L<IRC::Indexer>, providing an easy 
way to merge multiple trawled servers into a single network summary.

=head2 METHODS

=head3 add_server

Merges server information from a Trawl::Bot run.

Argument must be a L<IRC::Indexer::Info::Server> object.

=head3 netinfo

Returns the network information hash.

=head3 connectedat

Returns the connect timestamp of the last run for this network.

=head3 finishedat

Returns the timestamp of the last run for this network.

=head3 servers

Returns a hash keyed on server name.

=head3 lastserver

Returns the name of the last server added to this network.

=head3 motd_for

Returns the MOTD for a specified server:

  my $motd = $network->motd_for($servername);

=head3 users

Returns the global user count if available via B<LUSERS>

=head3 opers

Returns the global operator count if available via B<LUSERS>

=head3 channels

Returns the sorted array of parsed B<LIST> results, as described in 
L<IRC::Indexer::Trawl::Bot>

=head3 chanhash

Returns the hash containing parsed B<LIST> results, as described in 
L<IRC::Indexer::Trawl::Bot>


=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

L<http://www.cobaltirc.org>

=cut
