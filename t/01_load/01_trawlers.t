use Test::More tests => 7;

use File::Spec;

BEGIN {
  use_ok( 'IRC::Indexer' );
  use_ok( 'IRC::Indexer::Trawl::Bot' );
  use_ok( 'IRC::Indexer::Trawl::Forking') ;
  use_ok( 'IRC::Indexer::Trawl::Multi') ;
}

new_ok( 'IRC::Indexer::Trawl::Bot'     => [ Server => 'localhost']);
new_ok( 'IRC::Indexer::Trawl::Forking' => [ Server => 'localhost']);
new_ok( 'IRC::Indexer::Trawl::Multi'   => [ Servers => 
  [ 'localhost', [ '127.0.0.1', 6669 ] ]
]);
