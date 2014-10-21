package IRC::Indexer::Role::Client;

use strictures 1;

use Scalar::Util 'reftype';

use List::Objects::Types  -types;
use POEx::ZMQ::Types      -types;
use Types::Standard       -types;

use POE;
use POEx::ZMQ;

use Path::Tiny;


use Moo::Role; use MooX::late;
with 'MooX::Role::POE::Emitter';
requires
  qw/serialize deserialize/,            # ::Role::Serialize
  qw/cmd_dispatch dispatch_and_reply/,  # Role::CmdDispatch
;

# MXRP::Emitter
has '+event_prefix'     => ( default => sub { 'ircindex_' } );
has '+shutdown_signal'  => ( default => sub { 'SHUTDOWN_IRCINDEX_CLIENT' } );
# MXR::Pluggable:
has '+register_prefix'  => ( default => sub { 'IrcIndexer' } );


has dispatcher_endpoints => (
  lazy      => 1,
  is        => 'ro',
  isa       => TypedArray[ZMQEndpoint],
  predicate => 'has_dispatcher_endpoints',
  builder   => sub { [] },
);

has dispatcher_timeout => (
  lazy      => 1,
  is        => 'ro',
  isa       => StrictNum,
  builder   => sub { 180 },
);


has collector_endpoint => (
  lazy      => 1,
  is        => 'ro',
  isa       => Maybe[ZMQEndpoint],
  builder   => sub { undef },
);

has collector_timeout => (
  lazy      => 1,
  is        => 'ro',
  isa       => StrictNum,
  builder   => sub { 180 },
);

has zmq_context => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { POEx::ZMQ->context },
);


has _zmq_sock_dispatcher => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_DEALER],
  writer    => '_set_zmq_sock_dispatcher',
  builder   => sub {
    POEx::ZMQ->socket(
      event_prefix  => 'dispatcher_',
      context       => shift->zmq_context,
      type          => ZMQ_DEALER
    )
  },
);

has _zmq_idle_dispatcher => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_zmq_idle_dispatcher',
  builder   => sub { time },
);

has _zmq_sock_collector => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_DEALER],
  writer    => '_set_zmq_sock_collector',
  builder   => sub {
    POEx::ZMQ->socket(
      event_prefix  => 'collector_',
      context       => shift->zmq_context,
      type          => ZMQ_DEALER
    )
  },
);

has _zmq_idle_collector => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_zmq_idle_dispatcher',
  builder   => sub { 0 },
);


sub start {
  my ($self) = @_;

  $self->set_object_states([
    $self => +{
      emitter_started => '_emitter_started',
      emitter_stopped => '_emitter_stopped',

      dispatcher_recv_multi => '_zmq_dispatcher_recv',

      collector_recv_multi  => '_zmq_collector_recv',
    },
  ]);

  # FIXME set up HWMs, queuing behavior

  # FIXME connect out to Collector if we have one;
  #  send a HELLO
}

# FIXME POE counterparts for public methods

sub start_trawl {
  my ($self, $list) = @_;
  # FIXME
  #   Trawl list as iterable obj?
  #   Die if not ->has_dispatcher_endpoints
  #   Start idle timer, ping/pong dialog with dispatcher socket
  #   + timeout tracking
  #       should die if we've lost touch with all dispatchers
  #       should retry sending work if no acknowledgement in timeout period
  #        (ROUTER will round-robin automagically)
  #       should reset idle timer for ping/pong on any incoming socket
  #        activity
  #   Send serialized (JSON::MaybeXS?) trawl list
  #    DEALER will rr to dispatchers
}


sub find_results {
  my ($self, $netname_pattern, $servname_pattern) = @_;
  # FIXME ask Collector to look for strings (or glob-y patterns?)
  #   in $netname_pattern or $servname_pattern
}

sub get_results {
  my ($self, $netname) = @_;
  # FIXME ask Collector for results for $netname
  #   or all available
}

sub get_netnames {
  my ($self, $netname_pattern) = @_;
  # FIXME ask Collector for all available netnames
  #   or matching $netname_pattern
}


sub _emitter_started {
  # FIXME socket setup / connect
  # FIXME start timeout/heartbeating
}

sub _emitter_stopped {
  # FIXME shutdown cleanups?
}

sub _send_to_dispatcher {
  my ($self, $body) = @_;
  $self->_zmq_sock_dispatcher->send_multipart(
    '', $self->serialize($body)
  )
}

sub _send_to_collector {
  my ($self, $body) = @_;
  $self->_zmq_sock_collector->send_multipart(
    '', $self->serialize($body)
  )
}

sub _zmq_dispatcher_recv {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_set_zmq_idle_dispatcher( time );
  $self->dispatch_and_reply( dispatcher => $_[ARG0], $_[SENDER] )
}

sub _zmq_collector_recv {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_set_zmq_idle_collector( time );
  $self->dispatch_and_reply( collector => $_[ARG0], $_[SENDER] )
}


sub _recv_dispatcher_cmd_pong {
  # No-op, incoming PONG resets idle timers in _zmq_$component_recv
  ()
}

sub _recv_dispatcher_cmd_ack {
  # FIXME workload acknowledged
  #   reset workload timeout?
}


1;
