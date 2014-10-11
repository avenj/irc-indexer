package IRC::Indexer::Dispatcher;

# FIXME
#   provide ROUTER to talk to clients (REQ), trawlers (DEALER)
#   handle responding to PINGs
#   handle adding trawlers sending HELLO to seen hash
#   handle sending PINGs to previously-seen trawlers
#    & removing unresponsive trawlers from seen hash
#   handle trawler DISCONNECT by re-sending uncompleted work
#    to another trawler if available or queuing up and notifying client
#    of WAITING status
#   dispatch work to trawlers when client sends BATCH
#   -> client should be able to rr to multiple dispatchers,
#      remove a dispatcher and retry if multiples avail and request times out
#       (otherwise die)
#     client can disconnect after sending BATCH, results published later,
#     client can optionally SUB to Dispatcher's PUB for result retrieval
#    -> trawler forks bot, builds a report to serialize and send back
#       via its DEALER -> Dispatcher's ROUTER
#   handle REPORT from trawlers
#   publish REPORT on PUB sock for Collectors or Clients
#    Collector should provide pluggable backends, with defaults:
#     - memory
#     - locking DB_File if DB_File is avail
#     - SQLite (or generalized SQL via DBIx::Class, maybe sep pkg?)
#        if DBI/SQLite is avail
#    Collector should provide basic string-based search functionality
#     (trivial to impl in memory or sql)

use strictures 1;

use List::Objects::Types -types;

use POE;
use POEx::ZMQ;
use POEx::ZMQ::Types -types;

use Moo; use MooX::late;
with 'MooX::Role::POE::Emitter';

# MXRP::Emitter
has '+event_prefix'     => ( default => sub { 'ircindex_' } );
has '+shutdown_signal'  => ( default => sub { 'SHUTDOWN_IRCINDEX_SERVER' } );
# MXR::Pluggable:
has '+register_prefix'  => ( default => sub { 'IrcIndexer' } );


has zmq_context => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { POEx::ZMQ->context },
);


has _known_peers => (
  lazy      => 1,
  is        => 'ro',
  isa       => HashObj,
  coerce    => 1,
  builder   => sub { +{} },
);

has _sock_rtr_clients => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_ROUTER],
  clearer   => '_clear_sock_rtr_clients',
  predicate => '_has_sock_rtr_clients',
  builder   => sub {
    my ($self) = @_;
    POEx::ZMQ->socket(
      event_prefix => 'zmq_local_',
      context => $self->zmq_context,
      type    => ZMQ_ROUTER,
    )
  },
);

has _sock_rtr_peers => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_ROUTER],
  clearer   => '_clear_sock_rtr_peers',
  predicate => '_has_sock_rtr_peers',
  builder   => sub {
    my ($self) = @_;
    POEx::ZMQ->socket(
      event_prefix => 'zmq_remote_',
      context => $self->zmq_context,
      type    => ZMQ_ROUTER,
    )
  },
);

has _sock_pub_state => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_PUB],
  clearer   => '_clear_sock_pub_state',
  predicate => '_has_sock_pub_state',
  builder   => sub {
    my ($self) = @_;
    POEx::ZMQ->socket(
      context => $self->zmq_context,
      type    => ZMQ_PUB,
    )
  },
);

has _sock_sub_state => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_SUB],
  clearer   => '_clear_sock_sub_state',
  predicate => '_has_sock_sub_state',
  builder   => sub {
    my ($self) = @_;
    POEx::ZMQ->socket(
      event_prefix => 'zmq_state_',
      context => $self->zmq_context,
      type    => ZMQ_SUB,
    )
  },
);

sub _clear_all_sockets {
  my ($self) = @_;
  $self->_clear_sock_rtr_clients if $self->_has_sock_rtr_clients;
  $self->_clear_sock_rtr_peers   if $self->_has_sock_rtr_peers;
  $self->_clear_sock_pub_state   if $self->_has_sock_pub_state;
  $self->_clear_sock_sub_state   if $self->_has_sock_sub_state;
  $self->_known_peers->clear;
}


sub start {
  my ($self) = @_;

  $self->set_object_states([
    $self => +{
      emitter_started => '_emitter_started',
      emitter_stopped => '_emitter_stopped',

      zmq_state_recv            => '_zmq_state_recv',
      zmq_local_recv_multipart  => '_zmq_local_recv_multipart',
      zmq_remote_recv_multipart => '_zmq_remote_recv_multipart',
    },
  ]);

  $self->_start_emitter
}

sub stop {
  my ($self) = @_;
  $self->_shutdown_emitter
}

sub _emitter_started {
  # FIXME whiteboard socket identity mgmt?
  # FIXME socket setup / connect
  #  - bind:
  #  - connect:
  #  - subscribe '' on state sub
  # FIXME start timeout/heartbeating
}

sub _emitter_stopped {
  my ($self) = @_;
  $self->_clear_all_sockets;
}


sub _zmq_state_recv {
  # Peer announcing state to us.
  my ($kernel, $self, $msg) = @_[KERNEL, OBJECT, ARG0];
  
  my ($cmd, $rtr_id, $remote_total, $remote_busy) = split ' ', $msg;
  unless ($cmd eq 'STATE') {
    warn "Peer published unknown command $cmd";
    return
  }

  $self->_known_peers->{$rtr_id}->{workers_total} = $remote_total;
  $self->_known_peers->{$rtr_id}->{workers_busy}  = $remote_busy;

  # FIXME peer state accounting ($self->_known_peers hashobj)
  #   hash keyed on known peer server identities
  #    values containing known peer states
  #   manage it via heartbeating
}

sub _zmq_local_recv_multipart {
  # FIXME command input from local DEALER clients
  #  dispatcher for commands
}

sub _zmq_remote_recv_multipart {
  # FIXME command input from remote ROUTER peers
  #  dispatcher for commands
}

1;
