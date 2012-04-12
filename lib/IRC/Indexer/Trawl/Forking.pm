package IRC::Indexer::Trawl::Forking;

## Object and session to handle a forked trawler.

## Provide compatible methods w/ Bot::Trawl
## Other layers can use this with the same interface.

## - fork off Process::Trawler
## - pass opts
## - wait for reply
## - recreate info obj from reply
## - set done/failed/etc appropriately

use 5.12.1;
use strict;
use warnings;
use Carp;

use Config;

use POE qw/Wheel::Run Filter::Reference/;

use Time::HiRes;

require IRC::Indexer::Process::Trawler;

## Trawl::Bot compat:

sub new {
  my $self = {};
  my $class = shift;
  bless $self, $class;
  
  $self->{sessid} = undef;
  
  $self->{wheels}->{by_pid} = {};
  $self->{wheels}->{by_wid} = {};
  
  ## Grab and save same opts as Bot::Trawl
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  $self->{POST} = delete $args{postback}
    if $args{postback} and ref $args{postback};
  
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
        
        sess_sig_int
        
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
    return "Unknown failure, no server()" 
      if $self->done and not $self->report->server;
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
  $_[OBJECT]->kill_all; 
}

sub sess_sig_int {
  $_[OBJECT]->kill_all;
}

sub kill_all {
  my ($self) = @_;
  for my $pidof (keys %{ $self->{wheels}->{by_pid} }) {
    my $wheel = delete $self->{wheels}->{by_pid}->{$pidof};
    if (ref $wheel) {
      $wheel->kill(9);
    }
  }
  delete $self->{wheels}
}

sub _start {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  
  $kernel->sig('INT', 'sess_sig_int');
  $kernel->sig('TERM', 'sess_sig_int');
  
  $self->{sessid} = $_[SESSION]->ID();
  
  my $perlpath = $Config{perlpath};
  if ($^O ne 'VMS') {
    $perlpath .= $Config{_exe}
      unless $perlpath =~ m/$Config{_exe}$/i;
  }
  
  my $forkable;
  if ($^O eq 'MSWin32') {
    $forkable = \&IRC::Indexer::Process::Trawler::worker;
  } else {
    $forkable = [
      $perlpath,  (map { "-I$_" } @INC),
      '-MIRC::Indexer::Process::Trawler', '-e',
      'IRC::Indexer::Process::Trawler->worker()'
    ];
  }
  
  my $wheel = POE::Wheel::Run->new(
    Program => $forkable,
    ErrorEvent  => 'tr_error',
    StdoutEvent => 'tr_input',
    StderrEvent => 'tr_stderr',
    CloseEvent  => 'tr_closed',
    StdioFilter => POE::Filter::Reference->new(),
  );
  
  my $wheelid = $wheel->ID;
  my $pidof   = $wheel->PID;
  
  $kernel->sig_child($pidof, 'tr_sig_chld');

  $self->{wheels}->{by_pid}->{$pidof}   = $wheel;
  $self->{wheels}->{by_wid}->{$wheelid} = $wheel;

  ## Feed this worker the trawler conf.
  my $trawlercf = $self->{TrawlerOpts};
  my $item = [ $self->trawler_for, $trawlercf ];
  $wheel->put($item);
}

sub tr_input {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  my $input = $_[ARG0];

  ## Received report->clone()'d hash

  my ($server, $info_h) = @$input;
  unless (ref $info_h eq 'HASH') {
    warn "tr_input received invalid input from worker";
    return
  }

  ## Re-create Report::Server obj
  my $report = IRC::Indexer::Report::Server->new(
    FromHash => $info_h,
  );
  
  $self->{ReportObj} = $report;
  ## We're finished.
  $self->done(1);
  delete $self->{wheels};
  if (my $postback = delete $self->{POST}) {
    ## Send ourself in a postback.
    $postback->($self);
  }
}

sub tr_error {

}

sub tr_stderr {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  my ($err, $id) = @_[ARG0, ARG1];
  ## Report failed() and clean up
  $self->failed("Worker: $err");
}

sub tr_sig_chld {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  ## Worker's gone
  
  my $pidof = $_[ARG1];

  my $wheel = delete $self->{wheels}->{by_pid}->{$pidof};
  return unless ref $wheel;
  
  my $wheelid = $wheel->ID;
  delete $self->{wheels}->{by_wid}->{$wheelid};

  $self->failed("Worker: SIGCHLD")
    unless $self->done or $self->failed;
}

sub tr_closed {
  my ($self, $kernel) = @_[OBJECT, KERNEL];
  my $wheelid = $_[ARG0];
  my $wheel = delete $self->{wheels}->{by_wid}->{$wheelid};
  if (ref $wheel) {
    my $pidof = $wheel->PID;
    $wheel->kill(9);
    delete $self->{wheels}->{by_pid}->{$pidof};
  }
}

1;
__END__

=pod

=head1 NAME

IRC::Indexer::Trawl::Forking - Forking Trawl::Bot instances

=head1 SYNOPSIS

See L<IRC::Indexer::Trawl::Bot> for usage details.

This carries the same interface, but trawlers are forked off rather than 
run as asynchronous sessions.

=head1 DESCRIPTION

Uses L<POE::Wheel::Run> to manage forked trawlers running under their 
own Perl interpreter.

Carries exactly the same interface as L<IRC::Indexer::Trawl::Bot> and 
can be used interchangably.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
