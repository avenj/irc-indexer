use Test::More tests => 16;

use File::Spec;

BEGIN {
  use_ok( 'IRC::Indexer' );

  use_ok( 'IRC::Indexer::Trawl::Bot' );
  use_ok( 'IRC::Indexer::Trawl::Forking') ;
  use_ok( 'IRC::Indexer::Trawl::Multi') ;

  use_ok( 'IRC::Indexer::Report::Server') ;
  use_ok( 'IRC::Indexer::Report::Network') ;
  
  use_ok( 'IRC::Indexer::Conf') ;
  use_ok( 'IRC::Indexer::Logger') ;

  use_ok( 'IRC::Indexer::Output::JSON') ;
  use_ok( 'IRC::Indexer::Output::YAML') ;
  use_ok( 'IRC::Indexer::Output::Dumper') ;
}

new_ok( 'IRC::Indexer::Trawl::Bot'     => [ Server => 'localhost']);
new_ok( 'IRC::Indexer::Trawl::Forking' => [ Server => 'localhost']);
new_ok( 'IRC::Indexer::Trawl::Multi'   => [ Servers => 
  [ 'localhost', [ '127.0.0.1', 6669 ] ]
]);

new_ok( 'IRC::Indexer::Logger' => [ LogFile => File::Spec->devnull ]);
new_ok( 'IRC::Indexer::Conf' );
