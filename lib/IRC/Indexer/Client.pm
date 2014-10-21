package IRC::Indexer::Client;

use Moo;
with 'IRC::Indexer::Role::Serialize',
     'IRC::Indexer::Role::CmdDispatch',
     'IRC::Indexer::Role::Client';

1;
