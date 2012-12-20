package IRC::Indexer::Output::Dumper;

use Moo;
use Data::Dumper;

extends 'IRC::Indexer::Output';

around dump => sub {
  my ($orig, $self) = @_;
  $self->output( Dumper($self->input) );
  $self->$orig
};

around write => sub {
  my ($orig, $self) = splice @_, 0, 2;
  $self->output( Dumper($self->input) );
  $self->$orig(@_)
};

1;
__END__

=pod

=head1 NAME

IRC::Indexer::Output::Dumper - Data::Dumper output subclass

=head1 DESCRIPTION

L<IRC::Indexer::Output> subclass serializing via Data::Dumper.

See L<IRC::Indexer::Output> for usage details.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
