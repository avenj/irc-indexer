use strict; use warnings;
use Test::More tests => 3;
use POE;

BEGIN {
  use_ok( 'IRC::Indexer::Trawl::Multi' );
}

my $multi = new_ok( 'IRC::Indexer::Trawl::Multi' =>
 [
   Timeout => 2,
   Servers => [
     'Nonewhatsoever'.int(rand 666),
     ['Nonexistant'.int(rand 666), 6669],
     {
       Server => 'Nonexistant2'.int(rand 666),
       Port   => 7000,
     },
   ],
 ],
);

sub timeout {
  POE::Kernel->stop;
  fail("Timed out");
}

$SIG{ALRM} = 'timeout';

alarm 10;

diag("Trawl::Multi run, 2s timeout");

$multi->run;
POE::Kernel->run;

ok( $multi->done, "Trawler finished" );
