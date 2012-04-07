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

  $self->{State} = {};

  ## Outline of NetInfo just for ease of reference:
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
    ListChans   => [],     # available chan list    
    HashChans   => {},     # available chan hash
    MOTD        => undef,  # MOTD as array
    
    StartedAt   => time(),
    ConnectedAt => undef,
    FinishedAt  => undef,
  };

  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  $self->verbose($args{verbose} || 0);

  $self->{timeout}   = $args{timeout}  || 120;
  $self->{interval}  = $args{interval} || 10;

  $self->{ircserver} = $args{server} ? $args{server} 
                             : croak "No Server specified in new" ;
  $self->{ircport} = $args{port} ? $args{port} : 6667 ;
  $self->{ircnick} = $args{nickname} ? $args{nickname} : 'irctrawl'.(int rand 666);

  return $self
}

sub run {
  my ($self) = @_;
  
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
         'irc_365',
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

sub verbose {
  my ($self, $verbose) = @_;
  return $self->{verbose} = $verbose if defined $verbose;
  return $verbose
}

sub irc {
  my ($self, $irc) = @_;
  return $self->{ircobj} = $irc if $irc and ref $irc;
  return $self->{ircobj}
}

## Info accessors
## Most of these have aliases matching their hash key

sub netinfo {
  my ($self) = @_;
  return $self->{NetInfo}
}

sub connectedto {
  my ($self, $server) = @_;
  return $self->netinfo->{ConnectedTo} = $server if defined $server;
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
  my ($self, $status) = @_;
  return $self->netinfo->{Status} = $status if $status;
  return $self->netinfo->{Status}
}

sub netname { network(@_) }
sub network {
  my ($self, $netname) = @_;
  return $self->netinfo->{NetName} = $netname if $netname;
  return $self->netinfo->{NetName}
}

sub servername { server(@_) }
sub server {
  my ($self, $serv) = @_;
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
  my ($self, $count) = @_;
  return $self->netinfo->{OperCount} = $count if $count;
  return $self->netinfo->{OperCount} //= 0
}

sub globalusers { users(@_) }
sub users {
  my ($self, $global) = @_;
  return $self->netinfo->{GlobalUsers} = $global if $global;
  return $self->netinfo->{GlobalUsers}
}

sub listlinks { links(@_) }
sub links {
  ## arrayref
  my ($self, $linklist) = @_;
  return $self->netinfo->{ListLinks} = $linklist if $linklist
    and ref $linklist eq 'ARRAY' ;
  return $self->netinfo->{ListLinks}
  ## FIXME diff method to add a single server?
  ## FIXME diff method to return hash mapping servs -> servinfo ?
}

sub listchans { channels(@_) }
sub channels {
  ## arrayref, sorted (highest usercount first)
  my ($self, $chanlist) = @_;  
  return $self->netinfo->{ListChans} = $chanlist if $chanlist
    and ref $chanlist eq 'ARRAY' ;
  return $self->netinfo->{ListChans}  
}

sub hashchans { chanhash(@_) }
sub chanhash {
  ## hashref
  my ($self) = @_;
  return $self->netinfo->{HashChans}
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
  $self->irc( $irc );
  $irc->yield(register => 'all');
  $irc->yield(connect => {});
  $kernel->alarm( '_check_timeout', time + 10 );
}

sub _retrieve_info {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  ## called via alarm() (in irc_001)

  my $irc = $self->irc;
  
  ## set up hash appropriately:
  $self->connectedto( $self->{ircserver} );
  $self->servername( $irc->server_name );
  
  my $network = $irc->isupport('NETWORK') || $irc->server_name;
  $self->netname($network);
  
  ## yield off commands to grab anything else needed:
  ##  - LUSERS (maybe, unless we have counts already)
  ##  - LINKS
  ##  - LIST
  ## stagger them out at reasonable intervals to avoid flood prot:
  my $alrm = 2;
  for my $cmd (qw/list links lusers/) {
    $kernel->alarm_add('_issue_cmd', time + $alrm, $cmd);
    $alrm += $self->{interval};
  }
}

sub _issue_cmd {
  my ($self, $cmd) = @_[OBJECT, ARG0];
  
  ## most servers will announce lusers at connect-time:
  return if $cmd eq 'lusers' and $self->{State}->{Lusers};
  
  warn "-> issuing $cmd\n" if $self->verbose;
  $self->irc->yield($cmd);
}

sub _check_timeout {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->irc;
  my $info = $self->netinfo;
  
  my $shutdown = 0;
  
  my @states = qw/Links Lusers MOTD List/;
  my $stc = 0;
  for my $state (@states) {
    next unless $self->{State}->{$state};
    $stc++;
    warn "-> have state: $state\n" if $self->verbose;
  }
  
  $shutdown++ if $stc == scalar @states;

  my $startedat = $info->{StartedAt} || return;
  
  $shutdown++ if time - $startedat > $self->{timeout};

  if ($shutdown) {
    warn "-> shutdown\n" if $self->verbose;
    $self->done(1);
    $irc->yield('disconnect');
    $irc->yield('shutdown');  
  }
  
  $kernel->alarm( '_check_timeout', time + 10 );
}

## PoCo::IRC handlers

sub irc_connected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  ## report connected status; irc_001 handles the rest
  $self->status('INIT');
  $self->connectedat(time());
}

sub irc_disconnected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
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
  $self->status('CONNECTED');
  ## let things settle out, then _retrieve_info:
  $kernel->alarm('_retrieve_info', time + 6);
}

sub irc_375 {
  ## Start of MOTD
  my ($self, $server) = @_[OBJECT, ARG0];
  my $info = $self->netinfo;
  $self->blank_motd;
  $self->motd( "MOTD for $server:" );
}

sub irc_372 {
  ## MOTD line
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  $self->motd( $_[ARG1] );
}

sub irc_376 {
  ## End of MOTD
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  $self->motd( "End of MOTD." );  
  $self->{State}->{MOTD} = 1;
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

sub irc_365 {
  ## end of LINKS
  $_[OBJECT]->{State}->{Links} = 1;
}

sub irc_251 {
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  $self->{State}->{Lusers} = 1;
    
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
  $self->opercount($count);
}

sub irc_322 {
  ## LIST
  my ($self) = $_[OBJECT];
  my $info = $self->netinfo;
  my $split = $_[ARG2] // return;
  my ($chan, $users, $topic) = @$split;

  warn "chan -> $chan $users $topic\n" if $self->verbose;

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
  
  $self->{State}->{List} = 1;
  
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

IRC::Indexer::Trawl::Bot - indexing trawler instance

=head1 SYNOPSIS

  ## Inside a POE session:
  
  my $trawl = IRC::Indexer::Trawl::Bot->new(
    ## Server address and port:
    server  => 'irc.cobaltirc.org',
    port    => 6667,
    
    ## Nickname, defaults to irctrawl$rand:
    nickname => 'mytrawler',
    
    ## Overall timeout for this server:
    timeout => 120,
    
    ## Interval between commands (LIST/LINKS/LUSERS):
    interval => 10,
    
    ## Verbosity/debugging level:
    verbose => 0,
  );

  $trawl->run;
  
  ## Later:
  if ( $trawl->done ) {
    my $netinfo = $trawl->dump;
    ...
  }
  
  ## Spawn a bunch of trawlers in a loop:
  my $trawlers;
  for my $server (@servers) {
    $trawlers->{$server} = IRC::Indexer::Trawl::Bot->new(
      server => $server,
    )->run();
  }
  
  ## Check on them later:
  SERVER: for my $server (keys %$trawlers) {
    my $trawl = $trawlers->{$server};
    my $netinfo;
    ## dump() will return undef if we're not done:
    next SERVER unless $netinfo = $trawl->dump;
    . . . 
  }

=head1 DESCRIPTION

A single instance of an IRC::Indexer trawler.

Connects to a specified server, gathers some network information, and 
disconnects when either all requests appear to be fulfilled or the 
specified timeout (defaults to 120 seconds) is reached.

When the trawler is finished, $trawl->done will be boolean true; if 
there was some error, $trawl->failed will be true and will contain a 
scalar string describing the error.

The B<dump()> method returns a hash reference containing network 
information; see L</OUTPUT>, below.

The trawler attempts to be polite, spacing out requests for LINKS, 
LUSERS, and LIST; you can fine-tune the interval between commands by 
specifying a different B<interval> at construction (defaults to 15 
seconds).

=head1 OUTPUT

  my $info = $trawl->dump;

The hash returned by B<dump()> has the following keys:

=head2 Status

The status of the trawler; mostly used internally.

=head2 Failure

Error string as reported by $trawl->failure() -- used internally

=head2 ConnectedTo

The server address we originally connected to.

=head2 ServerName

The server's reported server name.

=head2 NetName

The network name as reported by B<ISUPPORT>, or the server's name if no 
NETWORK is reported.

=head2 GlobalUsers

The global user count as reported by L<LUSERS>.

=head2 OperCount

The global operator count as reported by B<LUSERS>.

=head2 ListLinks

An array containing the output of B<LINKS>; these are essentially raw 
lines without much parsing.

=head2 ListChans

An array of arrays, sorted by user count (highest first), of channel 
names and their respective user counts and topics:

  my @listchans = @{ $info->{ListChans} };
  for my $item (@listchans) {
    my ($name, $count, $topic) = @$item;
    . . .
  }

Essentially a pre-sorted L</HashChans>.

=head2 HashChans

A hash, keyed on channel name, of the results of B<LIST>.

Each channel has the keys B<Users> and B<Topic>:

  for my $chan (keys %{ $info->{HashChans} }) {
    my $this_chan  = $info->{HashChans}->{$chan};
    my $user_count = $this_chan->{Users};
    my $last_topic = $this_chan->{Topic};
    . . .
  }

=head2 MOTD

The server's returned MOTD, as an array reference.

=head2 StartedAt

The time (epoch seconds) that the trawler was constructed.

=head2 ConnectedAt

The time that the trawler connected to the IRC server.

=head2 FinishedAt

The time that the trawler finished.

=head1 METHODS

=head2 run

Start the trawler session.

=head2 failed

If a trawler has encountered an error, B<failed> will return true and 
contain a string describing the problem.

=head2 done

Returns boolean true if the trawler instance has finished.

=head2 dump

Returns the L</netinfo> hash if the trawler instance has finished, or 
undef if not.

=head2 netinfo

Returns the B<netinfo> hash described in L</OUTPUT> regardless of 
whether the trawler has finished.

=head2 connectedto

Returns the initially specified server name the trawler was instructed 
to connect to.

=head2 connectedat

Returns the time the bot connected to IRC (epoch seconds).

Returns undef if the bot is not connected.

=head2 startedat

Returns the time the trawler was constructed.

=head2 finishedat

Returns the time the trawler finished, or undef if the trawler is still 
running.

=head2 status

Returns the current status as a string.

=head2 network

Returns the reported network name, if there is one.

=head2 server

Returns the reported server name.

=head2 motd

Returns the MOTD as an array reference.

=head2 opers

Returns the operator count as reported by B<LUSERS>

=head2 users

Returns the global user count as reported by B<LUSERS>

=head2 links

Returns the link list as an array reference.

=head2 channels

Returns the channel list as described in B</OUTPUT>.

=head2 chanhash

Returns the channel hash as described in B</OUTPUT>.


=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
