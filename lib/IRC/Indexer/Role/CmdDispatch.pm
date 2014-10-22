package IRC::Indexer::Role::CmdDispatch;

use strictures 1;

use Scalar::Util 'reftype';

use POE;


use Role::Tiny;

requires 'serialize', 'deserialize';


sub dispatch_and_reply {
  my ($self, $type, $parts, $sender) = @_;
  if ( my $rv = $self->dispatch_cmd($type, $parts, $sender) ) {
    my (undef, $routes) = $parts->tail;
    $poe_kernel->post( $sender => send_multipart =>
      [ $routes->all, $self->serialize($rv) ]
    );
  }
   
}

sub dispatch_cmd {
  my ($self, $type, $parts, $sender) = @_;

  my $component = ucfirst $type;

  my ($body, $routes) = $parts->tail;
  unless ($body) {
    warn "Received empty content from $component ($self)\n";
    return
  }

  my $cmdhash = $self->deserialize($body);
  unless (reftype $cmdhash eq 'HASH') {
    warn
      "Expected HASH-type data from $component but got $cmdhash ($self)\n";
    return
  }

  my $cmd = lc( delete $cmdhash->{cmd} || '' );
  unless ($cmd && $cmd =~ /^[A-Za-z0-9_]+$/) {
    warn "Received invalid command '$cmd' from $component ($self)\n";
    return
  }
  my $meth = '_recv_' . $type . '_cmd_' . $cmd;
  unless ($self->can($meth)) {
    warn "Received unknown command '$cmd' from $component ($self)\n";
    return
  }

  $self->$meth($cmdhash, $routes, $sender)
}

1;
