package IRC::Indexer::Trawl::Bot;
our $VERSION = '0.10';

## feed me a server / port to connect to
## connect to the server / port
## grab relevant info, shove it into $self
## 
## if we have everything we need or timeout is up, disconnect
## provide a method that returns undef if we're in-progress, or net info hash

use 5.12.1;
use strict;
use warnings;
use Carp;

use POE;
use POE::Component::IRC::State;

## Methods

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;

  ## an outline of NetInfo just for ease of reference
  $self->{NetInfo} = {
    ## Status:
    ##  undef  = nuthin' doin'
    ##  'INIT' = socket is connected
    ##  'CONNECTED' = irc_001 has been received
    ##  'DONE' = finished
    ##  'FAIL' = error encountered, see ->{Failure}
    
    Status  => undef,
    Failure => undef,
     
    ConnectedTo => undef,  # where we tried to connect ($self->{ircserver})
    ServerName  => undef,  # announced server name
    NetName     => undef,  # announced NETWORK=
    GlobalUsers => undef,  # lusers
    OperCount   => undef,  # lusers
    ListLinks   => undef,  # available link list
    ListChans   => undef,  # available chan list    
    HashChans   => undef,  # available chan hash
    MOTD        => undef,  # MOTD as array
    
    StartedAt   => time(),
    ConnectedAt => undef,
    FinishedAt  => undef,
  };

  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  $self->{timeout}   = $args{timeout}  || 120;
  $self->{interval}  = $args{interval} || 20;

  $self->{ircserver} = $args{server} ? $args{server} 
                             : croak "No Server specified in new" ;
  $self->{ircport} = $args{port} ? $args{port} : 6667 ;
  $self->{ircnick} = $args{nickname} ? $args{nickname} : 'irctrawl'.(int rand 666);

  POE::Session->create(
    object_states => [
      $self => [
      
      ## Internals / PoCo::IRC:
      qw/
         _start
         
         _check_timeout
         _retrieve_info
         _issue_cmd
         
         irc_connected
         irc_001
         
         irc_disconnected
         irc_error
         irc_socketerr       
      /,
      
      ## Numerics:
        ## MOTD
         'irc_372',
         'irc_375',
         'irc_376',
        ## LINKS
         'irc_364',
        ## LUSERS
         'irc_251',
         'irc_252',
        ## LIST
         'irc_322',
         'irc_323',
    ] ],
  );


  return $self
}


## Info accessors

sub netinfo {
  my ($self) = @_;
  return $self->{NetInfo}
}

sub network {
  my ($self, $netname) = @_;
  return $self->netinfo->{NetName} = $netname if $netname;
  return $self->netinfo->{NetName}
}

sub server {
  my ($self, $serv) = @_;
  return $self->netinfo->{ServerName} = $serv if $serv;
  return $self->netinfo->{ServerName}
}

sub users {
  my ($self, $global) = @_;
  return $self->netinfo->{GlobalUsers} = $global if $global;
  return $self->netinfo->{GlobalUsers}
}

sub links {
  ## arrayref
  my ($self, $linklist) = @_;
  return $self->netinfo->{ListLinks} = $linklist if $linklist
    and ref $linklist eq 'ARRAY' ;
  return $self->netinfo->{ListLinks}
  ## FIXME diff method to add a single server?
  ## FIXME diff method to return hash mapping servs -> servinfo ?
}

sub channels {
  ## arrayref
  my ($self, $chanlist) = @_;  
  return $self->netinfo->{ListChans} = $chanlist if $chanlist
    and ref $chanlist eq 'ARRAY' ;
  return $self->netinfo->{ListChans}  
}

## Status accessors

sub failed {
  my ($self, $reason) = @_;
  my $info = $self->netinfo;
  if ($reason) {
    $info->{Status}     = 'FAIL';
    $info->{Failure}    = $reason;
    $info->{FinishedAt} = time;
  } else {
    return unless defined $info->{Status} 
           and $info->{Status} eq 'FAIL';
  }
  return $info->{Failure}
}

sub done {
  my ($self, $finished) = @_;
  my $info = $self->netinfo;
  
  if ($finished) {
    $info->{Status}     = 'DONE';
    $info->{FinishedAt} = time;
  }
  
  return unless defined $info->{Status} 
         and $info->{Status} ~~ [qw/DONE FAIL/];
  return $info->{Status}
}

sub dump {
  my ($self) = @_;
  my $info = $self->netinfo;
  ## return() if we're not done:
  return unless defined $info->{Status} 
         and $info->{Status} ~~ [qw/DONE FAIL/];
  ## else return hashref of net info (or failure status)
  ## that way masters can iterate through a pool of bots and check 'em
  ## frontends can serialize / store
  return $info
}


## POE (internal)

sub _start {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];

  my $irc = POE::Component::IRC->spawn(
    nick     => $self->{ircnick},
    username => 'ircindexer',
    ircname  => __PACKAGE__,
    server   => $self->{ircserver},
    port     => $self->{ircport},
  );
  $self->{ircobj} = $irc;
  $irc->yield(register => 'all');
  $irc->yield(connect => {});
  $kernel->alarm( '_check_timeout', time + 10 );
}

sub _retrieve_info {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};

  ## called via timer (in irc_001)
  
  ## set up hash appropriately:
  $self->netinfo->{ConnectedTo} = $self->{ircserver};  
  $self->netinfo->{ServerName}  = $irc->server_name;
  $self->netinfo->{NetName} = $irc->isupport('NETWORK')
                           || $irc->server_name;
  
  ## yield off commands to grab anything else needed:
  ##  - LUSERS
  ##  - LINKS
  ##  - LIST
  ## stagger them out at reasonable intervals to avoid flood prot:
  my $alrm = 2;
  for my $cmd (qw/lusers list links/) {
    $kernel->alarm('_issue_cmd', time + $alrm, $cmd);
    $alrm += $self->{interval};
  }
}

sub _issue_cmd {
  my ($self, $type) = @_[OBJECT, ARG0];
  my $irc = $self->{ircobj};
  $irc->yield($type);
}

sub _check_timeout {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  my $info = $self->netinfo;
  
  my $startedat = $info->{StartedAt} || return;
  
  if (time - $startedat > $self->{timeout}) {
    $self->done(1);
    $irc->yield('disconnect');
    $irc->yield('shutdown');
  }
  
  $kernel->alarm( '_check_timeout', time + 10 );
}

## PoCo::IRC handlers

sub irc_connected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## report connected status; irc_001 handles the rest
  $self->{NetInfo}->{Status} = 'CONNECTED';
  $self->{NetInfo}->{ConnectedAt} = time;
}

sub irc_disconnected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## we're done, clean up and report such 
  $self->done(1);
}

sub irc_socketerr {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $err = $_[ARG0];
  $self->failed("irc_socketerr: $err");
}

sub irc_error {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $err = $_[ARG0];
  ## errored out. clean up and report failure status
  $self->failed("irc_error: $err") unless $self->done;
}

sub irc_001 {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## let things settle out, then _retrieve_info:
  $kernel->alarm('_retrieve_info', time + 8);
}

sub irc_375 {
  ## Start of MOTD
  my ($self, $server) = @_[OBJECT, ARG0];
  my $info = $self->netinfo;
  $info->{MOTD} = [ "MOTD for $server:" ];
}

sub irc_372 {
  ## MOTD line
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  push(@{ $info->{MOTD} }, $_[ARG1]);
}

sub irc_376 {
  ## End of MOTD
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  push(@{ $info->{MOTD} }, "End of MOTD.");
}

sub irc_364 {
  ## LINKS, if we can get it
  ## FIXME -- also grab ARG2 and try to create useful hash
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $rawline;
  return unless $rawline = $_[ARG1];
  push(@{ $info->{ListLinks} }, $_[ARG1]);
}

sub irc_251 {
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $rawline;
  ## LUSERS
  ## may require some fuckery ...
  ## may vary by IRCD, but in theory it should be something like:
  ## 'There are X users and Y invisible on Z servers'
  return unless $rawline = $_[ARG2]->[0];
  my @chunks = split ' ', $rawline;
  my($users, $i);
  while (my $chunk = shift @chunks) {
    if ($chunk =~ /\d+/) {
      $users += $chunk;
      last if ++$i == 2;
    }
  }
  $info->{GlobalUsers} = $users || 0;
}

sub irc_252 {
  ## LUSERS oper count
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $rawline = $_[ARG1];
  my $count = substr($rawline, 0, 1);
  $count = 0 unless defined $count and $count =~ m/^\d+$/;
  $info->{OperCount} = $count;
}

sub irc_322 {
  ## LIST
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $split;
  return unless $split = $_[ARG2];
  my ($chan, $users, $topic) = @$split;
  return unless $chan;
  $users //= 0;
  $topic //= '';
  
  ## Add a hash element
  ## _323 triggers a ListChans rebuild, below
  $info->{HashChans}->{$chan} = {
    Topic => $topic,
    Users => $users,
  };
}

sub irc_323 {
  ## LIST ended
  ## sorted our hash into ListChans
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $chash = $info->{HashChans};
  return unless keys %$chash;
  
  my @sorted = sort { 
      $chash->{$b}->{Users} <=> $chash->{$a}->{Users} 
    } keys %$chash;

  $info->{ListChans} = [];
  for my $chan (@sorted) {
    my $users = $chash->{$chan}->{Users};
    my $topic = $chash->{$chan}->{Topic};
    push(@{ $info->{ListChans} }, [ $chan, $users, $topic ]);
  }
}

1;
__END__

=pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

=cut
