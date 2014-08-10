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


has server_endpoint => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);

has trawl_list => (
  required  => 1,
  is        => 'ro',
  isa       => InstanceOf['IRC::Indexer::Conf::TrawlList'],
);


has zmq_context => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { POEx::ZMQ->context },
);

has _zmq_sock => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket[ZMQ_DEALER],
  clearer   => '_clear_zmq_sock',
  builder   => sub {
    POEx::ZMQ->socket(
      context => shift->zmq_context,
      type    => ZMQ_DEALER
    )
  },
);


sub start {
  my ($self) = @_;

  $self->set_object_states([
    $self => +{
      emitter_started => '_emitter_started',
      emitter_stopped => '_emitter_stopped',

      zmq_recv => '_zmq_recv',
    },
  ]);
}

sub _emitter_started {
  # FIXME socket setup / connect
  # FIXME start timeout/heartbeating
}

sub _emitter_stopped {
  my ($self) = @_;
  $self->_clear_zmq_sock;
}

1;
