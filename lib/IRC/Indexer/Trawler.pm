package IRC::Indexer::Trawler;

use POE;
use POEx::IRC::Client::Lite;

use Types::Standard -types;

use Moo; use MooX::late;


has done => (
  lazy      => 1,
  is        => 'ro',
  isa       => Bool,
  writer    => '_set_done',
  default   => sub { 0 },
);

has post_when_done => (
  lazy      => 1,
  is        => 'ro',
  builder   => sub { undef },
);


has result => (
  lazy      => 1,
  is        => 'ro',
  isa       => HashRef,
  writer    => '_set_result',
  clearer   => '_clear_result',
  builder   => sub { +{} },
);


has server => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);

has port => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 6667 },
);

has timeout => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 320 },
);


sub BUILD {
  my ($self) = @_;
  POE::Session->create(
    object_states => [
        # FIXME
      $self => [ qw/
        _start
      / ],
    ],
  );
}


sub _start {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

}

# FIXME try to connect when obj is constructed
# FIXME timeout alarm
# FIXME handle IRC events
# FIXME post to post_when_done if avail when finished
#  (if session's resolvable)



1;
