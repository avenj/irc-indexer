package IRC::Indexer::Client;

use strictures 1;

use List::Objects::Types -types;

use POE;
use POEx::ZMQ;
use POEx::ZMQ::Types -types;

use Path::Tiny;

use Moo; use MooX::late;
with 'MooX::Role::POE::Emitter';

# MXRP::Emitter
has '+event_prefix'     => ( default => sub { 'ircindex_' } );
has '+shutdown_signal'  => ( default => sub { 'SHUTDOWN_IRCINDEX_CLIENT' } );
# MXR::Pluggable:
has '+register_prefix'  => ( default => sub { 'IrcIndexer' } );


has dispatcher_endpoint => (
  lazy      => 1,
  is        => 'ro',
  isa       => Maybe[ZMQEndpoint],
  builder   => sub { undef },
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
}

sub start_trawl {
  my ($self, $list) = @_;
  # FIXME
  #   Trawl list as iterable obj?
  #   Die if no dispatcher configured
  #   Start ping/pong dialog with dispatcher
  #     + accompanying timeout tracking
  #   Send serialized (JSON::MaybeXS?) trawl list
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
  my ($self) = @_;
  # FIXME shutdown cleanups?
}

sub _zmq_dispatcher_recv {
  # FIXME command dispatch
}

sub _zmq_collector_recv {
  # FIXME command dispatch
}

1;
