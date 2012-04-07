package IRC::Indexer::Output::Dumper;
our $VERSION = '0.01';

use Data::Dumper;

require IRC::Indexer::Output;
our @ISA = qw/IRC::Indexer::Output/;

sub write {
  my ($self, $path) = @_;
  
  my $input = $self->{Input};
  
  $self->{Output} = Dumper($input);
  
  $self->SUPER::write($path);
}

1;
__END__
