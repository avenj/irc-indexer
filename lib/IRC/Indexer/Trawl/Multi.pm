package IRC::Indexer::Trawl::Multi;

use 5.10.1;
use strict;
use warnings;
use Carp;

use POE;
use IRC::Indexer::Trawl::Bot;

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
  
  ## Spawn a session managing one trawler per server
  if ($args{servers} && ref $args{servers} eq 'ARRAY') {
    $self->{ServerList} = delete $args{servers};
  } else {
    croak "expected array of servers in servers =>"
  }
  
  $self->{Opts} = \%args;

  $self->{Trawlers}  = {};
  $self->{ResultSet} = {};
  
  return $self
}

sub run {
  my ($self) = @_;
  
  POE::Session->create(
    object_states => [
      $self => [
        '_start',
        '_stop',
        
        'm_check_trawlers',
      ],
    ],
  );
}

sub _stop {}

sub _start {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  ## spawn trawlers for {ServerList}
  my $servlist = $self->{ServerList};
  SERVER: for my $server (@$servlist) {
    my($server_name, $port);
    
    my $ircnick  = $self->{Opts}->{nickname};
    my $interval = $self->{Opts}->{interval};
    my $timeout  = $self->{Opts}->{timeout};
    
    my $ipv6 = 0;
    my $bindaddr = undef;
    
    if (ref $server eq 'ARRAY') {
      ($server_name, $port) = @$server;
    } elsif (ref $server eq 'HASH') {
      ## Passed a hash created from a server spec
      $server_name = $server->{Server}
      || croak "Passed a server configured hash with no Server defined";

      $port        = $server->{Port} || 6667;
      $ircnick     = $server->{Nickname} if $server->{Nickname};
      $bindaddr    = $server->{BindAddr} if $server->{BindAddr};
      $ipv6        = 1                   if $server->{UseIPV6};
      $timeout     = $server->{Timeout}  if $server->{Timeout};
      $interval    = $server->{Interval} if $server->{Interval};
    } else {
      $server_name = $server;
      $port = 6667;
    }
    
    $self->{Trawlers}->{$server} = IRC::Indexer::Trawl::Bot->new(
      Server   => $server,
      Port     => $port,
      Nickname => $ircnick,
      Interval => $interval,
      Timeout  => $timeout,
      BindAddr => $bindaddr,
      UseIPV6  => $ipv6,
    )->run();
  }
  
  ## spawn a timer to check on them
  $kernel->alarm('m_check_trawlers', time + 5);
}

sub m_check_trawlers {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  BOT: for my $server (keys %{ $self->{Trawlers} }) {
    my $trawler = $self->{Trawlers}->{$server};
    next BOT unless $trawler->done;
    
    my $ref = $trawler->dump;
    $self->{ResultSet}->{$server} = $ref;
  }

  if (keys %{$self->{ResultSet}} == keys %{$self->{Trawlers}}) {
    $self->done(1);
  } else {
    ## not done, reschedule
    $kernel->alarm('m_check_trawlers', time + 5);
  }

}

## Methods

sub done {
  my ($self, $finished) = @_;
  my $info = $self->{ResultSet};
  
  if ($finished) {
    ++$self->{Status}->{Done};
  }
  return $self->{Status}->{Done}
}

sub trawler {
  my ($self, $server) = @_;
  return unless $server and $self->{Trawlers}->{$server};
  return $self->{Trawlers}->{$server}
}

sub dump {
  ## dump the entire ResultSet
  my ($self) = @_;
  return unless $self->{Status}->{Done};
  return $self->{ResultSet}
}


1;
__END__

=pod

=head1 NAME

IRC::Indexer::Trawl::Multi - Trawl multiple IRC servers

=head1 SYNOPSIS

  ## Inside a POE session:
  
  my $multi = IRC::Indexer::Trawl::Multi->new(
    Servers => [
      'eris.cobaltirc.org',
      'raider.blackcobalt.net',
      [ 'phoenix.xyloid.org', '7000' ],
      {
        Server => 'irc.netlandtowers.com',
        Port   => 7000,
        UseIPV6 => 1,
        . . . 
      },
      . . .
    ],
    
    ## For other opts, see: perldoc IRC::Indexer::Trawl::Bot
  );
  
  $multi->run;
  
  ## Later:
  if ( $multi->done ) {
    my $trawled = $multi->dump;
    for my $server (keys %$trawled) {
      ## The server information hash:
      my $this_hash    = $trawled->{$server};
      
      ## Get IRC::Indexer::Trawl::Bot object:
      my $this_trawler = $multi->trawler($server);
      
      ## Get IRC::Indexer::Report::Server object:
      my $this_info    = $this_trawler->info;
      
      ## For parsing details, see:
      ##  perldoc IRC::Indexer::Trawl::Bot
      ##  perldoc IRC::Indexer::Report::Server
    }
  } else {
    ## Active trawlers remain.
  }

=head1 DESCRIPTION

A simple manager for groups of L<IRC::Indexer::Trawl::Bot> instances.

This is mostly an example; it is not used by any of the included 
controllers and is not at all sophisticated.

Given an array (reference) of server addresses, it will spawn trawlers 
for each server that run in parallel; when they're all finished, 
B<done()> will return boolean true and B<dump()> will return a hash 
reference, keyed on server name, of L<IRC::Indexer::Trawl::Bot> 
netinfo() hashes.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
