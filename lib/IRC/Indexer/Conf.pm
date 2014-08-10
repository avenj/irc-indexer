package IRC::Indexer::Conf;

use strictures 1;

use Path::Tiny;

use JSONY;
use Module::Runtime 'use_module';

use Types::Standard -types;

use Moo; use MooX::late;


has client => (
  lazy      => 1,
  is        => 'ro',
  isa       => InstanceOf['IRC::Indexer::Conf::Client'],
  coerce    => sub {
    use_module('IRC::Indexer::Conf::Client')->new(%{$_[0]})
  },
);

has server => (
  lazy      => 1,
  is        => 'ro',
  isa       => InstanceOf['IRC::Indexer::Conf::Server'],
  coerce    => sub {
    use_module('IRC::Indexer::Conf::Server')->new(%{$_[0]})
  },
);


sub new_from_path {
  my ($class, $path) = splice @_, 0, 2;
  confess "Expected a path to an IRC::Indexer conf"
    unless defined $path and path($path)->exists;

  my $cf = JSONY->new->load( path($path)->slurp_utf8 );

  if (@_) {
    my %tmp = @_; @{$cf}{keys %tmp} = values %tmp
  }

  (blessed $class || $class)->new(%$cf)
}


1;

=pod

=cut
