package IRC::Indexer::Output::JSON;

use Moo;
use JSON::XS;

extends 'IRC::Indexer::Output';

around dump => sub {
  my ($orig, $self) = @_;
  $self->output( 
    JSON::XS->new->utf8(1)->indent->encode(
      $self->input
    )
  );
  $self->$orig
};

around write => sub {
  my ($orig, $self) = splice @_, 0, 2;
  $self->output(
    JSON::XS->new->utf8(1)->indent->encode(
      $self->input
    )
  );
  $self->$orig(@_)
}


1;
__END__

=pod

=head1 NAME

IRC::Indexer::Output::JSON - JSON::XS output subclass

=head1 DESCRIPTION

L<IRC::Indexer::Output> subclass serializing via L<JSON::XS>.

See L<IRC::Indexer::Output> for usage details.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
