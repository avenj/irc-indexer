use Test::More tests => 35;

BEGIN {
  use_ok( 'IRC::Indexer::Info::Server' );
  use_ok( 'IRC::Indexer::Info::Network' );
}

my $server  = new_ok( 'IRC::Indexer::Info::Server'  );
my $network = new_ok( 'IRC::Indexer::Info::Network' );

ok( $server->connectedto('irc.cobaltirc.org'), 'connectedto() set' );
is( $server->connectedto, 'irc.cobaltirc.org', 'connectedto() get' );

my $ts = time;
ok( $server->connectedat($ts), 'connectedat() set' );
is( $server->connectedat, $ts, 'connectedat() get' );

ok( $server->startedat($ts), 'startedat() set' );
is( $server->startedat, $ts, 'startedat() get' );

ok( $server->finishedat($ts), 'finishedat() set' );
is( $server->finishedat, $ts, 'finishedat() get' );

ok( $server->status('DONE'), 'status() set' );
is( $server->status, 'DONE', 'status() get' );

ok( $server->server('eris.oppresses.us'), 'server() set' );
is( $server->server, 'eris.oppresses.us', 'server() get' );

ok( $server->network('blackcobalt'), 'network() set' );
is( $server->network, 'blackcobalt', 'network() get' );

ok( $server->motd("MOTD line"), 'motd() new motd' );
ok( $server->motd("MOTD line 2"), 'motd() append' );
my $motd;
ok( $motd = $server->motd, 'motd() get' );
is_deeply( $motd,
  [
    'MOTD line',
    'MOTD line 2',
  ],
  'MOTD compare'
);

ok( $server->opers(2), 'opers() set' );
is( $server->opers, 2, 'opers() get' );

ok( $server->users(5), 'users() set' );
is( $server->users, 5, 'users() get' );


ok( $server->add_channel('#oneuser', 1, 'topic string'),
  'add_channel one' 
);
ok( $server->add_channel('#twouser', 2, 'topic string 2') ,
  'add_channel two'
);
ok( $server->add_channel('#threeuser', 3, 'topic string 3'), 
  'add_channel three'
);

my $hashchans;
ok( $hashchans = $server->hashchans, 'hashchans() get' );
is_deeply( $hashchans,
  {
    '#oneuser' => {
      Users => 1,
      Topic => 'topic string',
    },
    
    '#twouser' => {
      Users => 2,
      Topic => 'topic string 2',
    },
    
    '#threeuser' => {
      Users => 3,
      Topic => 'topic string 3',
    },
  },
  'hashchans compare'
);

my $listchans;
ok( $listchans = $server->listchans, 'listchans() get' );
is_deeply( $listchans, 
  [
    [ '#threeuser', 3, 'topic string 3' ],
    [ '#twouser', 2, 'topic string 2'   ],
    [ '#oneuser', 1, 'topic string'     ],
  ],
  'listchans sort order'
);

my $dump;
ok( $dump = $server->info, 'info()' );
ok( ref $dump eq 'HASH', 'info() is a hash' );
