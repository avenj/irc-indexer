package IRC::Indexer::Trawl::Multi;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

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
  
  $self->{Opts} = $args;

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
        
        '_check_trawlers',
        
      ],
    ],
  );
}

sub _stop {}

sub _start {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  ## spawn trawlers for {ServerList}
  my $servlist = $self->{ServerList};
  for my $server (@$servlist) {
    $self->{Trawlers}->{$server} = IRC::Indexer::Trawl::Bot->new(
      Server   => $server,
      Port     => $self->{Opts}->{port},
      ircnick  => $self->{Opts}->{nickname},
      Interval => $self->{Opts}->{interval},
      Timeout  => $self->{Opts}->{timeout},
    )->run();
  }
  
  ## spawn a timer to check on them
  $kernel->alarm('_check_trawlers', time + 5);
}

sub _check_trawlers {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  
  BOT: for my $server (keys %{ $self->{Trawlers} }) {
    my $trawler = $self->{Trawlers}->{$server};
    next BOT unless $trawler->done;
    
    my $ref = $trawler->dump;
    $self->{ResultSet}->{$trawler} = $ref;
  }

  if (keys %{$self->{ResultSet}} == keys %{$self->{Trawlers}}) {
    ## FIXME we're done
  } else {
    ## not done, reschedule
    $kernel->alarm('_check_trawlers', time + 5);
  }

}

## Methods

sub done {

}

sub dump {

}

1;
