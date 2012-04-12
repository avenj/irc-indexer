package IRC::Indexer::Trawl::Bot;

use 5.12.1;
use strict;
use warnings;
use Carp;

use IRC::Indexer;

use IRC::Indexer::Report::Server;

use POE;
use POE::Component::IRC;
use POE::Component::IRC::Plugin::CTCP;

use IRC::Utils qw/
  decode_irc
  strip_color strip_formatting
/;

## Methods

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;

  $self->{State} = {};
  
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  $self->verbose($args{verbose} || 0);

  $self->{timeout}   = $args{timeout}  || 120;
  $self->{interval}  = $args{interval} || 10;

  $self->{ircserver} = $args{server} 
    || croak "No Server specified in new" ;
  $self->{ircport} = $args{port} || 6667 ;
  $self->{ircnick} = $args{nickname} || 'iindx'.(int rand 666);
  
  $self->{bindaddr} = $args{bindaddr} if $args{bindaddr};
  $self->{useipv6}  = $args{ipv6} || 0;

  return $self
}

sub trawler_for { return $_[0]->{ircserver} }

sub run {
  my ($self) = @_;

  $self->{Serv} = IRC::Indexer::Report::Server->new;
  $self->{Serv}->connectedto( $self->{ircserver} );
  
  POE::Session->create(
    object_states => [
      $self => [
      
      ## Internals / PoCo::IRC:
      qw/
         _start
         _stop
         shutdown
         
         b_check_timeout
         b_retrieve_info
         b_issue_cmd
         
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

  $self->{Serv}->startedat( time() );
}

sub verbose {
  my ($self, $verbose) = @_;
  return $self->{verbose} = $verbose if defined $verbose;
  return $verbose
}

sub irc {
  my ($self, $irc) = @_;
  return $self->{ircobj} = $irc if $irc;
  return $self->{ircobj}
}

sub report { info(@_) }
sub info {
  my ($self) = @_;
  return $self->{Serv}
}

## Status accessors

sub failed {
  my ($self, $reason) = @_;
  return unless ref $self->info;
  
  if ($reason) {
    carp "Trawl run failed: $reason" if $self->verbose;
    $self->info->status('FAIL');
    $self->info->failed($reason);
    $self->info->finishedat(time);
  } else {
    return unless defined $self->info->status 
           and $self->info->status eq 'FAIL';
  }
  return $self->info->failed
}

sub done {
  my ($self, $finished) = @_;
  
  if ($finished) {
    carp "Trawler completed: ".$self->info->connectedto
      if $self->verbose;
    $self->info->status('DONE');
    $self->info->finishedat(time());
  }

  return unless ref $self->info;  
  return unless defined $self->info->status 
         and $self->info->status ~~ [qw/DONE FAIL/];
  return $self->info->status
}

sub dump {
  my ($self) = @_;
  ## return() if we're not done:
  return unless ref $self->info;
  return unless defined $self->info->status 
         and $self->info->status ~~ [qw/DONE FAIL/];
  ## else return hashref of net info (or failure status)
  ## that way masters can iterate through a pool of bots and check 'em
  ## frontends can serialize / store
  return $self->info->netinfo
}

sub _stop {}
sub shutdown {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  
  $kernel->alarm('b_check_timeout') if ref $kernel;

  ## FIXME postback for finished trawlers?
  
  warn "-> Trawler shutdown called\n" if $self->verbose;

  $self->done(1);  
  $self->irc->call('shutdown')   if ref $self->irc;
  $self->irc(1);
}

sub _start {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  my %ircopts = (
    nick     => $self->{ircnick},
    username => 'ircindexer',
    ircname  => __PACKAGE__,
    server   => $self->{ircserver},
    port     => $self->{ircport},
    useipv6  => $self->{useipv6},
  );
  $ircopts{localaddr} = $self->{bindaddr} if $self->{bindaddr};
  
  my $irc = POE::Component::IRC->spawn( %ircopts );
  $self->irc( $irc );

  warn "-> Trawler spawned IRC\n" if $self->verbose;
  
  $irc->plugin_add('CTCP' =>
    POE::Component::IRC::Plugin::CTCP->new(
      version => __PACKAGE__.' '.$IRC::Indexer::VERSION,
    ),
  );
  
  $irc->yield(register => 'all');
  $irc->yield(connect => {});
  
  $kernel->alarm( 'b_check_timeout', time + 5 );
}

sub b_retrieve_info {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  ## called via alarm() (in irc_001)

  warn "-> Retrieving server information\n" if $self->verbose;

  my $irc = $self->irc;  
  
  my $info = $self->info;
  ## set up hash appropriately:
  my $server = $self->{ircserver};
  $info->servername( $irc->server_name );
  
  my $network = $irc->isupport('NETWORK') || $irc->server_name;
  $info->netname($network);
  
  ## yield off commands to grab anything else needed:
  ##  - LUSERS (maybe, unless we have counts already)
  ##  - LINKS
  ##  - LIST
  ## stagger them out at reasonable intervals to avoid flood prot:
  my $alrm = 2;
  for my $cmd (qw/list links lusers/) {
    $kernel->alarm_add('b_issue_cmd', time + $alrm, $cmd);
    $alrm += $self->{interval};
  }
}

sub b_issue_cmd {
  my ($self, $cmd) = @_[OBJECT, ARG0];
  
  ## most servers will announce lusers at connect-time:
  return if $cmd eq 'lusers' and $self->{State}->{Lusers};
  
  warn "-> Issuing: $cmd\n" if $self->verbose;
  $self->irc->yield($cmd);
}

sub b_check_timeout {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->irc;
  my $info = $self->info;
  
  my $shutdown = 0;
  
  my @states = qw/Links Lusers MOTD List/;
  my $stc = 0;
  for my $state (@states) {
    next unless $self->{State}->{$state};
    $stc++;
    warn "-> have state: $state\n" if $self->verbose;
  }
  
  $shutdown++ if $stc == scalar @states;

  my $connectedat = $info->connectedat || 0;
  $shutdown++ if time - $connectedat > $self->{timeout};

  if ($shutdown) {
    warn "-> Posting shutdown to own session\n" if $self->verbose;
    $kernel->post( $_[SESSION], 'shutdown' );
  }
  
  $kernel->alarm( 'b_check_timeout', time + 10 );
}

## PoCo::IRC handlers

sub irc_connected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  ## report connected status; irc_001 handles the rest
  my $info = $self->info;
  $info->status('INIT');
  $info->connectedat(time());
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
  $kernel->call( $_[SESSION], 'shutdown' );
}

sub irc_error {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $err = $_[ARG0];
  ## errored out. clean up and report failure status
  $self->failed("irc_error: $err") unless $self->done;
  $kernel->call( $_[SESSION], 'shutdown' );
}

sub irc_001 {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  $self->info->status('CONNECTED');
  ## let things settle out, then b_retrieve_info:
  $kernel->alarm('b_retrieve_info', time + 8);
}

sub irc_375 {
  ## Start of MOTD
  my ($self, $server) = @_[OBJECT, ARG0];
  my $info = $self->info;
  $info->blank_motd;
  $info->motd( "MOTD for $server:" );
}

sub irc_372 {
  ## MOTD line
  my ($self) = $_[OBJECT];
  my $info = $self->info;
  $info->motd( $_[ARG1] );
}

sub irc_376 {
  ## End of MOTD
  my ($self) = $_[OBJECT];
  my $info = $self->info;
  $info->motd( "End of MOTD." );  
  $self->{State}->{MOTD} = 1;
}

sub irc_364 {
  ## LINKS, if we can get it
  ## FIXME -- also grab ARG2 and try to create useful hash
  my ($self) = $_[OBJECT];
  my $rawline;
  return unless $rawline = $_[ARG1];
  push(@{ $self->{ListLinks} }, $_[ARG1]);
}

sub irc_365 {
  ## end of LINKS
  my $self = $_[OBJECT];
  $self->info->links( $self->{ListLinks} );
  $self->{State}->{Links} = 1;
}

sub irc_251 {
  my ($self) = $_[OBJECT];
  my $info = $self->info;
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
  $info->users($users||0)
}

sub irc_252 {
  ## LUSERS oper count
  my ($self) = $_[OBJECT];
  my $info = $self->info;
  my $rawline = $_[ARG1];
  my $count = substr($rawline, 0, 1);
  $count = 0 unless defined $count and $count =~ m/^\d+$/;
  $info->opers($count);
}

sub irc_322 {
  ## LIST
  my ($self) = $_[OBJECT];
  my $info = $self->info;
  my $split = $_[ARG2] // return;
  my ($chan, $users, $topic) = @$split;
  
  $chan  = decode_irc($chan);
  $topic = decode_irc(
    strip_color( strip_formatting($topic) )
  );
  
  $users //= 0;
  $topic //= ''; 
  
  ## Add a hash element
  $info->add_channel($chan, $users, $topic);
}

sub irc_323 {
  ## LIST ended
  my ($self) = $_[OBJECT];  
  $self->{State}->{List} = 1;
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
    Server  => 'irc.cobaltirc.org',
    Port    => 6667,
    
    ## Nickname, defaults to irctrawl$rand:
    Nickname => 'mytrawler',
    
    ## Local address to bind, if needed:
    BindAddr => '1.2.3.4',
    
    ## IPv6 trawler:
    UseIPV6 => 1,
    
    ## Overall timeout for this server:
    Timeout => 120,
    
    ## Interval between commands (LIST/LINKS/LUSERS):
    Interval => 10,
    
    ## Verbosity/debugging level:
    Verbose => 0,
  );

  $trawl->run;
  
  ## Later:
  if ( $trawl->done ) {
    my $info = $trawl->info;
    my $hash = $info->netinfo;
    . . .
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
    next SERVER unless $trawl->done;
    my $netname = $trawl->info->network;
    . . . 
  }

=head1 DESCRIPTION

A single instance of an IRC::Indexer trawler; this is the bot that forms 
the backbone of the rest of the IRC::Indexer modules and utilities.

Connects to a specified server, gathers some network information, and 
disconnects when either all requests appear to be fulfilled or the 
specified timeout (defaults to 120 seconds) is reached.

When the trawler is finished, $trawl->done() will be boolean true; if 
there was some error, $trawl->failed() will be true and will contain a 
scalar string describing the error.

The B<report()> method returns the L<IRC::Indexer::Report::Server> 
object.

The B<dump()> method returns a hash reference containing network 
information (or undef if not done); see L<IRC::Indexer::Report::Server> 
for details. This is the hash returned by 
L<IRC::Indexer::Report::Server/netinfo>

The trawler attempts to be polite, spacing out requests for LINKS, 
LUSERS, and LIST; you can fine-tune the interval between commands by 
specifying a different B<interval> at construction (defaults to 15 
seconds).

=head2 METHODS

=head3 trawler_for

Returns the server this trawler was constructed for.

=head3 run

Start the trawler session.

=head3 failed

If a trawler has encountered an error, B<failed> will return true and 
contain a string describing the problem.

=head3 done

Returns boolean true if the trawler instance has finished.

=head3 report

Returns the L<IRC::Indexer::Report::Server> object, from which server 
information can be retrieved.

Nonexistant until the trawler has been ->run().

=head3 dump

Returns the L</report> hash if the trawler instance has finished, or 
undef if not. See L<IRC::Indexer::Report::Server>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
