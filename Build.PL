use strict; use warnings;
use Module::Build;

my $build = Module::Build->new(
  module_name  => 'IRC::Indexer',
  dist_abstract => 'IRC network indexing system',
  dist_author   => 'Jon Portnoy <avenj@cobaltirc.org>',
  license => 'perl',
  
  create_makefile_pl => 'small',
  create_readme => 1,
  
  configure_requires => {
    'Module::Build' => '0.38',
  },
  
  build_requires => {
    'Test::More' => 0,
  },
  
  requires => {
    'perl' => '5.12.1',
    'Data::Dumper' => 0,
    'Getopt::Long' => 0,
    'Storable' => 0,
    
    'POE::Component::IRC::State' => '6.74',
    
    'JSON::XS' => 0,
    'YAML::XS' => 0,
  },
);

$build->create_build_script;
