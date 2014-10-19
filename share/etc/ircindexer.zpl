# IRC::Indexer cfg in ZPL format; see Text::ZPL & ZeroMQ RFC 4
#
# You need only configure the pieces you are running on the local system;
# other sections can be safely ignored (or commented out, at your option).

collector
    # Dispatcher's PUB socket:
    subscribe = 'tcp://127.0.0.1:6660'
    # Subscribe to more dispatchers:
    # subscribe = 'tcp://1.2.3.4:6660'
    # subscribe = ...

dispatcher
    endpoints
        # Command (ROUTER) socket:
        server    = 'tcp://127.0.0.1:6650'
        # Result/log publisher (PUB) socket:
        publisher = 'tcp://127.0.0.1:6660'

    logging
        # Set to a true value to publish log messages to clients or collectors:
        log_to_publisher = 1
        # Set to a true value & set a log_file to write log messages to disk:
        log_to_file = 0
        log_file    = '/path/to/logfile'

trawler
    # Dispatcher's 'server' (ROUTER) socket:
    dispatcher = 'tcp://127.0.0.1:6650'
    # Maximum # of concurrent (forked) IRC connections per server:
    max_bots   = 4
