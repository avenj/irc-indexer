package IRC::Indexer::Output::YAML;
our $VERSION = '0.01';

use YAML::XS;

require IRC::Indexer::Output;
our @ISA = qw/IRC::Indexer::Output/;

sub write {
  my ($self, $path) = @_;
  
  my $input = $self->{Input};
  
  $self->{Output} = Dump($input);
  
  $self->SUPER::write($path);
}

1;
__END__
