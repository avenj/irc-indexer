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
    ListLinks   => undef,  # available link list
    ListChans   => undef,  # available chan list    
    
    StartedAt   => time(),
    ConnectedAt => undef,
    FinishedAt  => undef,
  };

  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  $self->{ircserver} = $args{server} ? $args{server} 
                             : croak "No Server specified in new" ;
  $self->{ircport} = $args{port} ? $args{port} : 6667 ;
  $self->{ircnick} = $args{nickname} ? $args{nickname} : 'irctrawl'.(int rand 666);

  POE::Session->create(
    object_states => [
      $self => [
        '_start',
        
        '_check_timeout',
        '_retrieve_info',

        'irc_connected',
        'irc_disconnected',
        'irc_error',
        'irc_001',
 
      ],
    ],
  );


  return $self
}


## Info accessors

sub network {
  my ($self, $netname) = @_;
  return $self->{NetName} = $netname if $netname;
  return $self->{NetName}
}

sub server {
  my ($self, $serv) = @_;
  return $self->{ServerName} = $serv if $serv;
  return $self->{ServerName}
}

sub users {
  my ($self, $global) = @_;
  return $self->{GlobalUsers} = $global if $global;
  return $self->{GlobalUsers}
}

sub links {
  ## arrayref
  my ($self, $linklist) = @_;
  return $self->{ListLinks} = $linklist if $linklist
    and ref $linklist eq 'ARRAY' ;
  return $self->{ListLinks}
  ## FIXME diff method to add a single server?
  ## FIXME diff method to return hash mapping servs -> servinfo ?
}

sub channels {
  ## arrayref
  my ($self, $chanlist) = @_;  
  return $self->{ListChans} = $chanlist if $chanlist
    and ref $chanlist eq 'ARRAY' ;
  return $self->{ListChans}  
  ## FIXME diff method to add a single channel
  ## FIXME array of hashes of chaninfo, sorted by users?
}

## Status accessors

sub failed {
  my ($self) = @_;
  my $info = $self->{NetInfo};
  return unless defined $info->{Status} 
         and $info->{Status} = 'FAIL';
  return $info->{Failure}
}

sub done {
  my ($self) = @_;
  my $info = $self->{NetInfo};
  return unless defined $info->{Status} 
         and $info->{Status} ~~ qw/DONE FAIL/;
  return $info->{Status}
}

sub dump {
  my ($self) = @_;
  my $info = $self->{NetInfo};
  ## return() if we're not done:
  return unless defined $info->{Status} 
         and $info->{Status} ~~ qw/DONE FAIL/;
  ## else return hashref of net info (or failure status)
  ## that way masters can iterate through a pool of bots and check 'em
  ## frontends can serialize / store
  return $info
}


## POE

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
  $irc->yield(register => 'all');  # FIXME?
  $irc->yield(connect => {});
}

sub _retrieve_info {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## FIXME
  ## called via timer
  ## set up hash appropriately
  ## yield off commands to grab anything else needed
  ## stagger them out at reasonable intervals to avoid flood prot  
}

sub _check_timeout {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};

  ## FIXME configurable timeout
  ## if we've been on the server more than X secs and still can't 
  ## dump() stats, give up for now
}



sub irc_connected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## report connected status; irc_001 handles the rest
}

sub irc_disconnected {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## we're done, clean up and report such 
}

sub irc_error {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};
  ## errored out. clean up and report failure status
}

sub irc_001 {
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $irc = $self->{ircobj};

  ## FIXME timer to let things settle out, then grab info
}

1;
__END__

=pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

=cut
