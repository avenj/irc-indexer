package IRC::Indexer::Logger;
our $VERSION = '0.01';

use 5.12.1;
use strict;
use warnings;
use Carp;

use Scalar::Util qw/blessed/;

use Log::Handler;

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  ## Set up a Log::Handler for specified LogFile
  
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
  
  $self->{LogFile} = $args{logfile}
    || croak "No LogFile specified in new()";
  
  $self->{LogLevel} = $args{loglevel} || 'info' ;
  
  $self->logger( $self->_create_logger );
  
  return $self
}

sub _create_logger {
  my ($self) = @_;
  my $logger = Log::Handler->new();
  $logger->add(
    file => {
      maxlevel => $self->{LogLevel},
      timeformat => "%Y/%m/%d %H:%M:%S",
      message_layout => "[%T] %L %p %m",
      
      filename => $self->{LogFile},
      filelock => 1,
      fileopen => 1,
      reopen   => 1,
      utf8     => 1,
      autoflush => 1,
    },
  );
 
  return $logger
}

sub logger {
  my ($self, $logger) = @_;
  ## Return/set our Log::Handler
  return $self->{LogObj} = $logger if blessed $logger;
  return $self->{LogObj}
}

sub log_to {
  ## Adjust the log destination
  my ($self, $path) = @_;
  return unless $path;
  $self->{LogFile} = $path;
  $self->logger->flush;
  $self->logger( $self->_create_logger );
  return $self->logger
}

1;
__END__
=pod

=head1 NAME

IRC::Indexer::Logger - simple interface to Log::Handler

=head1 SYNOPSIS

  my $handler = IRC::Indexer::Logger->new(
    ## Path to output file:
    LogFile  => $logfile_path,

    ## Typically 'debug', 'info', 'warn':
    LogLevel => 'info',
  );

  ## Switch to a different file:
  $handler->log_to($new_logfile);
  
  ## Access the actual logger:
  my $logger = $handler->logger;
  
  ## Log things:
  $logger->info("Something informative");
  $logger->warn("Something went wrong!");
  $logger->debug("Things are happening.");
  
=head1 DESCRIPTION

Simplified construction of Log::Handler instances for IRC::Indexer 
frontends.

See the SYNOPSIS for usage details.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
