package IRC::Indexer::Process::JSONify;

## Forkable JSON encoder.
## Process refs, encode JSON, return to master and die.

## Pass me a reference:
##  ->put([ $json, $network, $server_name ])
## Get back JSON:
##  [ $json, $network, $server_name ]

use strict;
use warnings;

use IRC::Indexer::Output::JSON;

use Storable qw/nfreeze thaw/;

use bytes;

sub worker {
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
        
        my ($hash, $network, $server) = @$inputref;
        die "Invalid arguments for worker"
          unless ref $hash eq 'HASH';

        my $jsify = IRC::Indexer::Output::JSON->new(
          Input => $hash,
        );
        
        my $json = $jsify->dump;
        
        ## Returns:
        ##  [ $network, $server_name, $json ]
        my $frozen = nfreeze( [ $json, $network, $server ] );
        my $stream  = length($frozen) . chr(0) . $frozen ;
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
