package IRC::Indexer::Output::JSON;

use strict;
use warnings;
use JSON::XS;

require IRC::Indexer::Output;
our @ISA = qw/IRC::Indexer::Output/;

sub dump {
  my ($self) = @_;
  my $input = $self->{Input};
  my $json = JSON::XS->new->utf8(1)->pretty->encode($input);
  $self->{Output} = $json;
  $self->SUPER::dump();
}

sub write {
  my ($self, $path) = @_;
  my $input = $self->{Input};
  $self->{Output} = encode_json($input) ."\n";
  $self->SUPER::write($path);
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
