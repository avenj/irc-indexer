package IRC::Indexer::Info::Server;
our $VERSION = '0.01';

## A single server.

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  $self->{NetInfo} = {};
  return $self
}

sub netinfo {
  my ($self) = @_;
  ## Add ListChans before a netinfo dump:
  $self->_sort_listchans;
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
  return $self->netinfo->{ServerName} = $serv if $serv;
  return $self->netinfo->{ServerName}
}

sub blank_motd {
  my ($self) = @_;
  $self->netinfo->{MOTD} = [];
}

sub motd {
  my ($self, $line) = @_;
  push(@{ $self->netinfo->{MOTD} }, $line) if $line;
  return $self->netinfo->{MOTD}
}

sub opercount { opers(@_) }
sub opers {
  my ($self, $opers) = @_;
  return $self->netinfo->{OperCount} = $count
    if defined $count;
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
  return $self->netinfo->{ListLinks}//[]
  ## FIXME better links handling
}

sub listchans { channels(@_) }
sub channels {
  my ($self, $list) = @_;
  return $self->netinfo->{ListChans} = $chanlist
    if $chanlist and ref $chanlist eq 'ARRAY';
  return $self->netinfo->{ListChans}//[]
}

sub hashchans { chanhash(@_) }
sub chanhash {
  my ($self, $hash) = @_;
  return $self->netinfo->{HashChans} = $hash 
    if $hash and ref $hash eq 'HASH';
  return $self->netinfo->{HashChans}//{}
}

sub add_channel {
  my ($self, $channel, $users, $topic) = @_;
  return unless $channel;
  $users //= 0;
  $topic //= '';
  $self->netinfo->{HashChans}->{$chan} = {
    Topic => $topic,
    Users => $users,
  };
  return $channel
}

sub _sort_listchans {
  my ($self) = @_;
  my $chash = $self->netinfo->{HashChans}//{};
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

=cut
