package IRC::Indexer::Process::Trawler;

## Object and session to handle a forked trawler.

## Provide compatible methods w/ Bot::Trawl
## Other layers can use this with the same interface.

## - fork off Trawl::Forkable
## - pass opts
## - wait for reply
## - recreate info obj from reply
## - set done/failed/etc appropriately

use 5.12.1;
use strict;
use warnings;
use Carp;

use POE qw/Wheel::Run Filter::Reference/;

use Time::HiRes;

require IRC::Indexer::Trawl::Forkable;

## Trawl::Bot compat:

sub new {
  my $self = {};
  my $class = shift;
  
  $self->{sessid} = undef;
  
  $self->{wheels}->{by_pid} = {};
  $self->{wheels}->{by_wid} = {};
  
  ## Grab and save same opts as Bot::Trawl
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
  
  $self->{TrawlerOpts} = \%args;
  
  croak "No Server specified in new()"
    unless $self->{TrawlerOpts}->{server};
  
  return $self
}

sub run {
  my ($self) = @_;
  ## Create POE session to manage forked Bot::Trawl
  
  POE::Session->create(
    object_states => [
      $self => [ qw/
        _start
        _stop
        shutdown
        
        tr_sig_chld
        
        tr_input
        tr_error
        tr_stderr
      / ],
    ],
  );
  
}

sub trawler_for { return $_[0]->{TrawlerOpts}->{server} }

sub done {
  my ($self, $finished) = @_;
  
  if ($finished) {
    $self->report->status('DONE');
    $self->report->finishedat(time);
  }
  
  return unless ref $self->report;
  return unless defined $self->report->status
    and $self->report->status ~~ [qw/DONE FAIL/];
  return $self->report->status
}

sub failed {
  my ($self, $reason) = @_;
  
  if ($reason) {
    $self->report->status('FAIL');
    $self->report->failed($reason);
    $self->report->finishedat(time);
  } else {
    return unless ref $self->report;
    return unless defined $self->report->status
      and $self->report->status eq 'FAIL';
  }
  
  return $self->report->failed
}

sub dump {
  my ($self) = @_;

  return unless ref $self->report;
  return unless defined $self->report->status
    and $self->report->status ~~  [ qw/DONE FAIL/ ];
  return $self->report->netinfo
}

sub report { info(@_) }
sub info {
  return $_[0]->{ReportObj}
}


## POE:

sub _stop {
  ## FIXME call our 'shutdown'
}

sub shutdown {
  ## FIXME kill(9) wheels if any
}

sub _start {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  
  $self->{sessid} = $_[SESSION]->ID();
  
  my $perlpath = $Config{perlpath};
  if ($^O ne 'VMS') {
    $perlpath .= $Config{_exe}
      unless $perlpath =~ m/$Config{_exe}$/i;
  }
  
  my $forkable;
  if ($^O) eq 'MSWin32') {
    $forkable = \&IRC::Indexer::Trawl::Forkable::worker;
  } else {
    $forkable = [
      $perlpath,  (map { "-I$_" } @INC),
      '-MIRC::Indexer::Trawl::Forkable', '-e',
      'IRC::Indexer::Trawl::Forkable->worker()'
    ];
  }
  
  my $wheel = POE::Wheel::Run->new(
  
  );
  
  ## Fork and handle our IRC::Indexer::Trawl::Forkable
}

sub tr_input {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  my $input = $_[ARG0];

  ## Received report->clone()'d hash

  my ($network, $server, $info_h) = @$input;
  unless (ref $info_h eq 'HASH') {
    warn "tr_input received invalid input from worker";
    return
  }

  ## Re-create Report::Server obj
  my $report = IRC::Indexer::Report::Server->new(
    FromHash => $info_h,
  );
  
  $self->{ReportObj} = $report;
  
  $self->done(1);
}

sub tr_error {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  ## Error, report failed() and clean up
}

sub tr_stderr {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  ## Error, report failed() and clean up
}

sub tr_sig_chld {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  ## Worker's gone
}

1;
__END__
