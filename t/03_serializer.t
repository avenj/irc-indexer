use Test::More tests => 1;

BEGIN {
  use_ok( 'IRC::Indexer::Output::JSON' );
  use_ok( 'IRC::Indexer::Output::YAML' );
  use_ok( 'IRC::Indexer::Output::Dumper' );
}


