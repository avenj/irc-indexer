package IRC::Indexer::Output::YAML;

use Moo;
use YAML::XS ();

extends 'IRC::Indexer::Output';

around dump => sub {
  my ($orig, $self) = @_;
  $self->output( YAML::XS::Dump($self->input) );
  $self->$orig
};

around write => sub {
  my ($orig, $self) = splice @_, 0, 2;
  $self->output( YAML::XS::Dump($self->input) );
  $self->$orig(@_)
};


1;
__END__

=pod

=head1 NAME

IRC::Indexer::Output::YAML - YAML::XS output subclass

=head1 DESCRIPTION

L<IRC::Indexer::Output> subclass serializing via L<YAML::XS>.

See L<IRC::Indexer::Output> for usage details.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
