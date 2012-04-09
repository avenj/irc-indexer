package IRC::Indexer;
our $VERSION = '0.01';

## stub! for now ..

1;
__END__

=pod

=head1 NAME

IRC::Indexer - IRC server indexing via POE

=head1 SYNOPSIS

  ## Pull stats from a single server:
  $ ircindexer-single -s irc.cobaltirc.org -f JSON -o cobaltirc.json

  ## Generate some example confs:
  $ ircindexer-examplecf -t httpd -o httpd.cf
  $ $EDITOR httpd.cf

  $ mkdir networks/
  $ cd networks/
  $ mkdir cobaltirc
  $ ircindexer-examplecf -t spec -o cobaltirc/eris.oppresses.us.server
  $ $EDITOR cobaltirc/eris.oppresses.us.server
  . . .
  
  ## Spawn a httpd serving JSON:
  $ ircindexer-server-json -c httpd.cf

=head1 DESCRIPTION

A set of modules and utilities useful for trawling IRC networks, 
collecting information, and exporting it to portable formats for use in 
Web frontends and other applications.

FIXME frontends

See the B<perldoc> for L<IRC::Indexer::Trawl::Bot> for more about 
using the trawl bot itself as part of other POE-enabled applications.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
