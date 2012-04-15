use strict; use warnings;
use Test::More tests => 18;
use POE;

my @compat;

BEGIN {
  @compat = qw/
    IRC::Indexer::Trawl::Bot
    IRC::Indexer::Trawl::Forking
  /;
  use_ok($_) for @compat;
}

for my $class (@compat) {
  diag($class);
  
  POE::Session->create(
    inline_states => {
      '_start' => sub {
        my $trawler = new_ok( $class => [
           Server   => 1,
           Timeout  => 3,
           Postback => $_[SESSION]->postback('trawler_done'),
         ],
        );
        
        ok( $trawler->run, 'Trawler run()' );
        my $sid;
        ok( $sid = $trawler->ID(), 'Trawler ID()' );
      },
      
      'trawler_done' => sub {      
        pass( 'Received postback' );
        
        my $trawler = $_[ARG1]->[0];
        
        isa_ok( $trawler, $class );
        ok( $trawler->done, 'Trawler reports completion' );
        ok( $trawler->failed, 'Trawler reports failed' );
        isa_ok( $trawler->report, 'IRC::Indexer::Report::Server' );
        $_[KERNEL]->post( $trawler->ID, 'shutdown' );
      },
    },
  );
  
  $poe_kernel->run;

}
