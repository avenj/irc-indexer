package IRC::Indexer::Process::JSONify;

## Forking JSON encoder.
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
  $0 = "ircindexer ENCODE" unless $^O eq 'MSWin32';
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
__END__
=pod

=head1 NAME

IRC::Indexer::Process::JSONify - Forking JSON encoder

=head1 SYNOPSIS

See B<ircindexer-server-json>

=head1 DESCRIPTION

A small forkable JSON encoder, usable by L<POE::Wheel::Run> wheels to 
externally encode JSON.

Given an array containing a hash, a network name, and possibly a server 
name, returns an array containing a JSON hash, network name, and server 
name (possibly undef).

See: L<POE::Wheel::Run> and L<POE::Filter::Reference>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
