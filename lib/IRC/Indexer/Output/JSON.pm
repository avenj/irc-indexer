package IRC::Indexer::Output::JSON;
our $VERSION = '0.01';

use JSON::XS;

require IRC::Indexer::Output;
our @ISA = qw/IRC::Indexer::Output/;

sub write {
  my ($self, $path) = @_;
  
  my $input = $self->{Input};
  
  $self->{Output} = encode_json($input);
  
  $self->SUPER::write($path);
}

1;
__END__
