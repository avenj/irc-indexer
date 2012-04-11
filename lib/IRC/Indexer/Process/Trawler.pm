package IRC::Indexer::Process::Trawler;

## Handled by Trawl::Forking

use strict;
use warnings;

use POE;

require IRC::Indexer::Trawl::Bot;

use Storable qw/nfreeze thaw/;

use bytes;

sub worker {
  $0 = "ircindexer TRAWL" unless $^O eq 'MSWin32';
  POE::Kernel->stop;

  binmode STDOUT;
  binmode STDIN;
  
  STDOUT->autoflush(1);
  
  my $buf = '';
  my $read_bytes;
  
  while (1) {
    if (defined $read_bytes) {
      if (length $buf >= $read_bytes) {
        my $inputref = thaw( substr($buf, 0, $read_bytes, "") );
        $read_bytes = undef;

        ## Note: $server here is the "target server" (ConnectedTo)
        ## Not necessarily "Reported server name" (ServerName)
        ## Same for reply to master.
        my ($server, $conf) = @$inputref;
        die "Trawl::Forkable passed invalid configuration"
          unless ref $conf eq 'HASH';
        
        $0 = "ircindexer TRAWL $server" unless $^O eq 'MSWin32';
        
        my $trawler = IRC::Indexer::Trawl::Bot->new(%$conf);
        $trawler->run();
        
        POE::Kernel->run();
        
        die $trawler->failed if $trawler->failed;
        
        my $report = $trawler->report->clone() || {
          NetName     => $server,
          ServerName  => $server,
          ConnectedTo => $server,
          FinishedAt  => time,
          Status => 'FAIL', 
          Failed => 'report() retrieval failure in Trawl::Forkable',
        };
        
        my $frozen = nfreeze([ $server, $report ]);
        my $stream = length($frozen) . chr(0) . $frozen ;
        my $written = syswrite(STDOUT, $stream);
        die $! unless $written == length $stream;
        exit 0
      }
    } elsif ($buf =~ s/^(\d+)\0//) {
      $read_bytes = $1;
      next
    }
  
    my $readb = sysread(STDIN, $buf, 4096, length $buf);
    last unless $readb;
  }
  
  exit 0
}

1;
