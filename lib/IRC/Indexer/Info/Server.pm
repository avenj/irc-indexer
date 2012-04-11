package IRC::Indexer::Info::Server;

use 5.12.1;
use strict;
use warnings;
use Carp;

use Storable qw/dclone/;

## A single server.

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
  
  if ($args{fromhash} && ref $args{fromhash} eq 'HASH') {
    ## given a previously-created hash
    ## does no validation currently
    $self->{NetInfo} = dclone($args{fromhash});
  } else {
    $self->{NetInfo} = {};
  }
  return $self
}

sub clone {
  my ($self) = @_;
  return dclone($self->{NetInfo})
}

sub info { netinfo(@_) }
sub netinfo {
  my ($self) = @_;
  return $self->{NetInfo}
}

sub connectedto {
  my ($self, $server) = @_;
  return $self->netinfo->{ConnectedTo} = $server if $server;
  return $self->netinfo->{ConnectedTo}
}

sub connectedat {
  my ($self, $ts) = @_;
  return $self->netinfo->{ConnectedAt} = $ts if defined $ts;
  return $self->netinfo->{ConnectedAt}
}

sub startedat {
  my ($self, $ts) = @_;
  return $self->netinfo->{StartedAt} = $ts if defined $ts;
  return $self->netinfo->{StartedAt}
}

sub finishedat {
  my ($self, $ts) = @_;
  return $self->netinfo->{FinishedAt} = $ts if defined $ts;
  return $self->netinfo->{FinishedAt}
}

sub status {
  ## undef = nuthin' doin'
  ## INIT  = socket connected
  ## CONNECTED = irc_001
  ## DONE = finished
  ## FAIL = error encountered
  my ($self, $status) = @_;
  return $self->netinfo->{Status} = $status
    if defined $status;
  return $self->netinfo->{Status}
}

sub failed {
  my ($self, $reason) = @_;
  ## set a failure reason and FAIL status
  if ($reason) {
    $self->status('FAIL');
    $self->netinfo->{Failure} = $reason;    
  }
  return $self->netinfo->{Failure}
}

sub netname { network(@_) }
sub network {
  my ($self, $netname) = @_;
  return $self->netinfo->{NetName} = $netname
    if $netname;
  return $self->netinfo->{NetName}
}

sub servername { server(@_) }
sub server {
  my ($self, $server) = @_;
  return $self->netinfo->{ServerName} = $server if $server;
  return $self->netinfo->{ServerName}
}

sub blank_motd {
  my ($self) = @_;
  $self->netinfo->{MOTD} = [];
}

sub motd {
  my ($self, $line) = @_;
  push(@{ $self->netinfo->{MOTD} }, $line) if $line;
  return dclone($self->netinfo->{MOTD})
}

sub opercount { opers(@_) }
sub opers {
  my ($self, $opers) = @_;
  return $self->netinfo->{OperCount} = $opers
    if defined $opers;
  return $self->netinfo->{OperCount}
}

sub globalusers { users(@_) }
sub users {
  my ($self, $global) = @_;
  return $self->netinfo->{GlobalUsers} = $global
    if defined $global;
  return $self->netinfo->{GlobalUsers}
}

sub listlinks { links(@_) }
sub links {
  my ($self, $linklist) = @_;
  return $self->netinfo->{ListLinks} = $linklist
    if $linklist and ref $linklist eq 'ARRAY';
  return dclone($self->netinfo->{ListLinks}//[])
  ## FIXME better links handling
}

sub chancount { totalchans(@_) }
sub totalchans {
  my ($self) = @_;
  return $self->netinfo->{ChanCount}
}

sub listchans { channels(@_) }
sub channels {
  my ($self, $chanlist) = @_;
  return $self->netinfo->{ListChans} = $chanlist
    if $chanlist and ref $chanlist eq 'ARRAY';
  $self->_sort_listchans;
  return dclone($self->netinfo->{ListChans}//[])
}

sub hashchans { chanhash(@_) }
sub chanhash {
  my ($self, $hash) = @_;
  return $self->netinfo->{HashChans} = $hash 
    if $hash and ref $hash eq 'HASH';
  return dclone($self->netinfo->{HashChans}//{})
}

sub add_channel {
  my ($self, $channel, $users, $topic) = @_;
  return unless $channel;
  $users //= 0;
  $topic //= '';
  $self->netinfo->{HashChans}->{$channel} = {
    Topic => $topic,
    Users => $users,
  };
  ++$self->netinfo->{ChanCount};
  return $channel
}

sub _sort_listchans {
  my ($self) = @_;
  my $chash = $self->netinfo->{HashChans}//{};
  return unless keys %$chash;
  my @sorted = sort {
      $chash->{$b}->{Users} <=> $chash->{$a}->{Users}
    } keys %$chash;
  $self->netinfo->{ListChans} = [];
  for my $chan (@sorted) {
    my $users = $chash->{$chan}->{Users};
    my $topic = $chash->{$chan}->{Topic};
    push(@{ $self->netinfo->{ListChans} }, [ $chan, $users, $topic ] );
  }
}

1;
__END__


=pod

=head1 NAME

IRC::Indexer::Info::Server - Server information class for IRC::Indexer

=head1 SYNOPSIS

  ## Create new blank server info obj:
  my $info = IRC::Indexer::Info::Server->new;

  . . . add trawler data .  . .
  
  ## Get server's info as hash:
  my $ref = $info->netinfo;
  
  ## Construct from previously-exported hash:
  my $info = IRC::Indexer::Info::Server->new(
    FromHash => $previous->netinfo(),
  );
  
  ## See below for other methods.

=head1 DESCRIPTION

Represents the results of a single trawled server.

=head2 Methods

=head3 netinfo

Returns the entire NetInfo hash, as documented below (L</netinfo hash>).

=head3 status

Get or set the current status.

Valid values are:

  undef     -- not started
  INIT      -- started
  CONNECTED -- connected to IRC
  FAIL      -- error encountered
  DONE      -- finished

=head3 failed

Get or set the current error string.

Should be boolean false if there have been no fatal errors.

=head3 startedat

Get or set the start timestamp (epoch seconds)

=head3 connectedat

Get or set the time the trawler connected to IRC.

=head3 finishedat

Get or set the time the trawler finished this run.

=head3 network

Get or set the network name; this is the name announced via B<ISUPPORT> 
(NETWORK=). If the queried network doesn't announce NETWORK=, the server 
name will be supplied.

=head3 connectedto 

Get or set the target server; this is the address the bot is trawling, 
not necessarily the announced server name (see L</server>)

=head3 server

Get or set the actual server name; this is the name announced by the 
server, not necessarily the address we originally connected to.

=head3 blank_motd

Clear the existing MOTD.

=head3 motd

With no arguments, gets the current MOTD (or undef). This will be an 
array reference containing MOTD lines.

If an argument is specified, it is pushed to the end of the current MOTD 
array.

=head3 users

Get or set the current global user count, as reported by B<LUSERS>.

=head3 opers

Get or set the current global oper count, as reported by B<LUSERS>.

=head3 links

With no arguments, returns an array reference containing LINKS output 
(or undef).

If an argument is specified, it should be an array reference containing 
raw LINKS lines.

=head3 totalchans

Get the total number of channels found in B<LIST>.

This is calculated from L</chanhash> and cannot be set directly; use 
L</add_channel> to add a channel.

=head3 channels

Returns an array of arrays, sorted by user count (highest first), of 
channel names and their respective user counts and topics:

  my $listchans = $info->channels;
  for my $item (@$listchans) {
    my ($name, $count, $topic) = @$item;
    . . .
  }

=head3 chanhash

Returns a hash, keyed on channel name, of the results of B<LIST>.

Keys are B<Users> and B<Topic>:

  my $chans = $info->chanhash;
  for my $channel (keys %$chans) {
    my $this_chan = $chans->{$channel};
    my $user_count = $this_chan->{Users};
    my $last_topic = $this_chan->{Topic};
    . . . 
  }

=head3 add_channel

Used internally by trawlers.

Adds a channel to the channel hash (see L</chanhash>):

  ## in a LIST handler:
  $info->add_channel($chan, $users, $topic);

=head2 netinfo hash

The B<netinfo> method returns a hash with the following keys:

  Status
  Failure
  ConnectedTo
  ServerName
  NetName
  GlobalUsers
  OperCount
  ListLinks
  ListChans
  MOTD
  StartedAt
  ConnectedAt
  FinishedAt

These all roughly correspond to their respective accessors, documented 
above.

See L<IRC::Indexer::POD::ServerSpec> for details.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
