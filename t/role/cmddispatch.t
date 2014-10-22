use Test::More;
use strict; use warnings FATAL => 'all';

use List::Objects::WithUtils;

use POE;

no warnings 'redefine';
sub POE::Kernel::post {
  my (undef, undef, $ev, $parts) = @_;
  cmp_ok $ev, 'eq', 'send_multipart',
    'send_multipart posted ok';
  ok @$parts == 3, 'received expected number of parts';
}

{ package My::Dispatching; use strict; use warnings;
  use Moo; 
  with 
    'IRC::Indexer::Role::Serialize',
    'IRC::Indexer::Role::CmdDispatch';
  use Test::More;
  my $x = 0;
  sub _recv_foo_cmd_bar {
    ++$x;
    pass "Received cmd 'bar' of type 'foo' ($x)"
  }
}

my $dispatcher = My::Dispatching->new;

my @params = ( foo =>
  array(
    123,
    '',
    $dispatcher->serialize(+{
      cmd => 'bar',
      paramA => 'quux',
      paramB => 'weeble',
    }),
  ),
  'sender'
);

$dispatcher->dispatch_cmd(@params);
$dispatcher->dispatch_and_reply(@params);

done_testing
