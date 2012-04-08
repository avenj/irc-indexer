use Test::More tests => 6;

BEGIN {
  use_ok( 'IRC::Indexer::Trawl::Bot' );
  use_ok( 'IRC::Indexer::Trawl::Multi') ;
  use_ok( 'IRC::Indexer::Info::Server') ;
  use_ok( 'IRC::Indexer::Output::JSON') ;
  use_ok( 'IRC::Indexer::Output::YAML') ;
  use_ok( 'IRC::Indexer::Output::Dumper') ;
}
