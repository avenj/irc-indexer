package IRC::Indexer::Conf;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

use File::Find;

use YAML::XS;

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  return $self  
}

sub parse_conf {
  my ($self, $path) = @_;
  
  ## FIXME
  ## try to load a YAML conf file
  ## format for these may vary
}

sub parse_nets {
  my ($self, $dir) = @_;
  
  my $nethash = {};
  
  my @specfiles = $self->find_nets($dir);

  SERV: for my $specpath (@specfiles) {
    ## FIXME
    ## try to load YAML conf (parse_conf)
    ## create conf hash keyed on network name
    ## containing per-server configuration values
  }

  return $nethash;
}

sub find_nets {
  my ($self, $dir) = @_;
  
  croak "find_nets called with no NetworkDir"
    unless $dir;
  
  croak "find_nets called against non-directory $dir"
    unless -d $dir;
  
  my @found;
  find(
    sub {
      my $thisext = (split /\./)[-1] // return;
      push(@found, $File::Find::name)
        if $thisext eq 'server';
    },
    $dir
  );
  return @found;
}

sub slurp {
  my ($path) = @_;
  my $slurped;
  open my $fh, '<', $path or croak "open failed: $!";
  { local $/; $slurped = <$fh> }
  close $fh;
  return $slurped
}


## Example CF

sub example_cf_spec {
  my $conf = <<END;
---
### Example server spec file

Network: CobaltIRC
Server: eris.oppresses.us
Port: 6667
# Defaults are probably fine here:
#Nickname:
#BindAddr:
#UseIPV6:
#Timeout: 90
#Interval: 15

END

  return $conf
}

sub example_cf_multi {
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

  return $conf
}

sub write_example_cf {
  my ($self, $path, $conf) = @_;
  open my $fh, '>', $path or die "open failed: $!\n";
  print $fh $conf;
  close $fh;
}

1;
__END__
