package IRC::Indexer::Conf;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

use File::Find;


sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class
  return $self  
}

sub parse_conf {

}

sub parse_nets {

}

sub find_nets {

}

sub slurp {
  my ($path) = @_;
  my $slurped;
  open my $fh, '<', $path or croak "open failed: $!";
  { local $/; $slurped = <$fh> }
  close $fh;
  return $slurped
}

## Accessors


## Example CF

sub example_cf {
  ## write an example config
  my ($path) = @_;
  my $conf = <<END;
---
### Example ircindexer-multi config

## NetworkDir:
##
## Network spec files will be found recursively under NetworkDir:
## A network spec file should end in ".server"
## These specs tie networks together under their specified Network:
## The files should be YAML, looking something like:
#   ---
#   Network: CobaltIRC
#   Server: eris.oppresses.us
#   Port: 6667
#   Timeout: 90
#   Interval: 15
##
NetworkDir: /home/ircindex/networks

## LogFile:
##
## An optional action log.
LogFile: /home/ircindex/indexer.log

## Format:
##
## The output subclass to use. One of: JSON, YAML, Dumper
Format: YAML

## OutputType:
##
## One of: Network, Server, All
## Determines how flatfile output will be saved.
##
## If OutputType is 'Network', servers belonging to a particular
## network name are consolidated into one file per network.
##
## If OutputType is 'Server', output is split into one file per
## server.
##
## If OutputType is 'All', output is saved to one giant file
## covering all networks trawled.
OutputType: Network

## OutputDir:
##
## Destination for output files; must be a directory.
OutputDir: /home/ircindex/trawled

END

  open my $fh, '>', $path or die "open failed: $!\n";
  print $fh $conf;
  close $fh;
}

1;
__END__
