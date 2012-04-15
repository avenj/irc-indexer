use Test::More tests => 4;

use File::Spec;

BEGIN {
  use_ok( 'IRC::Indexer::Conf') ;
  use_ok( 'IRC::Indexer::Logger') ;
}

new_ok( 'IRC::Indexer::Logger' => [ LogFile => File::Spec->devnull ]);
new_ok( 'IRC::Indexer::Conf' );
