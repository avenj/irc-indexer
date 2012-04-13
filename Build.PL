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
    
    'Carp'         => 0,
    'POSIX'        => 0,
    'Getopt::Long' => 0,
    'Scalar::Util' => 0,
    'Digest::SHA'  => 0,
    
    'File::Find' => 0,
    'File::Path' => 0,
    'File::Spec' => 0,
    
    'Time::HiRes' => 0,
    
   ## Logging
    'Log::Handler' => 0,

   ## POE
    'POE' => '1.311',

   ## IRC
    'IRC::Utils' => 0,
    'POE::Component::IRC' => '6.74',

   ## HTTP
    'URI' => 0,
    'POEx::HTTP::Server' => 0,    
   
   ## Serialization
    'JSON::XS' => 0,
    'YAML::XS' => 0,
    'Data::Dumper' => 0,
    'Storable'     => 0,
    'DB_File'      => 0,
    'Compress::Zlib' => 0,
  },
);

$build->create_build_script;
