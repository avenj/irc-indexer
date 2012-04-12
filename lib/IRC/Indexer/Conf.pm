package IRC::Indexer::Conf;

use 5.12.1;
use strict;
use warnings;
use Carp;

use File::Find;

use Storable qw/dclone/;

use YAML::XS ();

sub new { bless {}, shift }

sub slurp {
  my ($self, $path) = @_;
  my $slurped;
  open my $fh, '<:encoding(utf8)', $path or croak "open failed: $!";
  { local $/; $slurped = <$fh> }
  close $fh;
  return $slurped
}

sub parse_conf {
  my ($self, $path) = @_;
  
  unless (-e $path && -r $path) {
    croak "Could not read conf at $path: $!"
  }
  
  my $yaml = $self->slurp($path);
  
  croak "No data returned from $path" unless $yaml;

  my $ref = YAML::XS::Load($yaml);
  
  return $ref
}

sub parse_nets {
  my ($self, $dir) = @_;
  
  my $nethash = {};
  
  my @specfiles = $self->find_nets($dir);

  SERV: for my $specpath (@specfiles) {
    my $this_spec = $self->parse_conf($specpath);
    
    unless ($this_spec->{Server}) {
      croak "specfile missing Server definition: $specpath"
    }
    
    unless ($this_spec->{Network}) {
      croak "specfile missing Network definition: $specpath"
    }

    unless ( index($this_spec->{Network}, '%') == -1 ) {
      croak "'%' is not valid in network names"
    }
    
    my $servname = $this_spec->{Server};
    my $netname  = $this_spec->{Network};
    
    $nethash->{$netname}->{$servname} = dclone($this_spec);
  }

  return $nethash
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

  return wantarray ? @found : \@found ;
}


## Example CF

sub get_example_conf { get_example_cf(@_) }
sub get_example_cf {
  my ($self, $cftype) = @_;
  my $method = 'example_cf_'.$cftype;
  
  unless ($self->can($method)) {
    croak "Invalid example conf type: $cftype"
  }

  return $self->$method
}

sub write_example_conf { write_example_cf(@_) }
sub write_example_cf {
  my ($self, $cftype, $path) = @_;
  croak "write_example_cf requires a type and path"
    unless $cftype and $path;
  
  my $conf = $self->get_example_cf($cftype); 

  open my $fh, '>', $path or die "open failed: $!\n";
  print $fh $conf;
  close $fh;
}

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

sub example_cf_httpd {
  my $conf = <<END;
---
### Example HTTPD conf

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

## CacheDir:
##
## Large pools of trawlers will store quite a bit of data after 
## a few runs have completed.
## This trades some performance for significant memory savings.
##
## You probably want this.
##
## If a CacheDir is not specified, resultsets will live in memory;
## additionally, due to the nature of the forking encoders,
## there will be some extra processing overhead when results are 
## cached.
CacheDir: /home/ircindex/jsoncache

## MaxEncoders:
##
## Workers are forked off to handle the potentially expensive 
## JSON encoding of server trawl results.
## Default should be fine; you're only going to hit it on very 
## expansive trawlers.
#MaxEncoders: 10

## ListChans:
##
## If ListChans is enabled, the server will create sorted lists of 
## channels as documented in IRC::Indexer::POD::ServerSpec
##
## Expensive in terms of CPU and space.
ListChans: 0

## ServerPort:
##
## Port to run this HTTPD instance on.
ServerPort: 8700

## BindAddr:
##
## Optional address to bind to.
#BindAddr: '0.0.0.0'

## LogFile:
##
## Path to log file.
## If omitted, no logging takes place.
LogFile: /home/ircindex/indexer.log

## LogLevel:
##
## Log verbosity level.
## 'debug', 'info', or 'warn'
LogLevel: info

## LogHTTP:
##
## If true, log HTTP-related activity
## Defaults to ON
LogHTTP: 1

## LogIRC:
##
## If true, log trawling-related activity
## Defaults to ON
LogIRC: 1

END

  return $conf
}

1;
__END__

=pod

=head1 NAME

IRC::Indexer::Conf - Handle Indexer configuration files

=head1 SYNOPSIS

  my $cfhash = IRC::Indexer::Conf->parse_conf($path);
  
  ## Recursively read server spec files:
  my $nethash = IRC::Indexer::Conf->parse_nets($specfile_dir);

=head1 DESCRIPTION

Handles IRC::Indexer configuration files in YAML format.

This module can also generate example configuration files.

=head1 METHODS

Methods can be called as either class or object methods.

=head2 parse_conf

Takes a file path.

Read and parse a specified YAML configuration file, returning the 
deserialized contents.

=head2 parse_nets

Calls L</find_nets> on a specified directory and processes all of the 
returned server spec files.

  IRC::Indexer::Conf->parse_nets($spec_dir);

Returns a hash with the following structure:

  $NETWORK => {
    $ServerA => $spec_file_hash,
  }

=head2 find_nets

Locate C<.server> spec files recursively under a specified directory.

  my @specfiles = IRC::Indexer::Conf->find_nets($spec_dir);

Returns an array in list context or an array reference in scalar 
context.

=head2 get_example_cf

Returns the raw YAML for an example configuration file.

  IRC::Indexer::Conf->get_example_cf('httpd');

Valid types, as of this writing, are:

  httpd
  spec

=head2 write_example_cf

Writes an example configuration file to a specified path.

  IRC::Indexer::Conf->write_example_cf('httpd', $path);
  
  ## From a shell, perhaps:
  $ perl -MIRC::Indexer::Conf -e \
    'IRC::Indexer::Conf->write_example_cf("httpd", "myhttpd.cf")'

See L</get_example_cf> for a list of valid types.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
