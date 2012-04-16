use Test::More tests => 12;
use strict; use warnings;
use File::Spec;

BEGIN {
  use_ok( 'IRC::Indexer::Logger') ;
  use_ok( 'IRC::Indexer::Conf') ;
}

## IRC::Indexer::Logger

my $logobj = new_ok( 'IRC::Indexer::Logger' => [ LogFile => 
  File::Spec->devnull 
]);
isa_ok( $logobj->logger, 'Log::Handler' );
$logobj = undef;

$logobj = new_ok( 'IRC::Indexer::Logger' => [ DevNull => 1 ] );
my $logger = $logobj->logger;
ok( $logger->add(screen => { log_to => "STDOUT", maxlevel => "debug" }),
  "Add logger to STDOUT"
);

my $stdout;
{
  local *STDOUT;
  open STDOUT, '>', \$stdout
    or die $!;
  $logger->warn("Warning");
  $logger->info("Information");
  $logger->debug("Debug");
  close STDOUT or die $!;
}
ok( $stdout, "Got log on STDOUT" );

my @lines = split /\n/, $stdout;
is(scalar @lines, 3, "Got warn, info, debug" );

## IRC::Indexer::Conf

new_ok( 'IRC::Indexer::Conf' );

my $mycf = <<CONF;
---
Scalar: "String"
Array:
  - one
  - two
Hash:
  Key: value

CONF

my $fh;
ok( open($fh, '<', \$mycf), 'Scalar FH open' );
my $cf;
ok( $cf = IRC::Indexer::Conf->parse_conf($fh), 'parse_conf()' );
is_deeply( $cf,
  {
    Scalar => "String",
    Array  => [ "one", "two" ],
    Hash   => { Key => "value" },
  },
  'parse_conf() compare'
);

