package IRC::Indexer::Server;

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
  $self->_clear_zmq_sock;
}


sub _zmq_state_recv {
  my ($kernel, $self, $msg) = @_[KERNEL, OBJECT, ARG0];
  # FIXME peer announcing state to us
}

sub _zmq_local_recv_multipart {
  # FIXME command input from local DEALER clients
}

sub _zmq_remote_recv_multipart {
  # FIXME command input from remote ROUTER peers
}

1;
