use Test::More;
use strict; use warnings FATAL => 'all';

use IRC::Indexer::Conf;

my $cf = IRC::Indexer::Conf->new_from_file("share/etc/ircindexer.zpl");

cmp_ok $cf->collector->subscribe, 'eq', 'tcp://127.0.0.1:6660',
  'accessing deep elements ok';

ok $cf->dispatcher && $cf->trawler, 'top-level elements ok';

done_testing
