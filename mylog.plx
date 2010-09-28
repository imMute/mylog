#!/usr/bin/perl
#####   CONFIGURATION   #####
# Database must have schema version 3.1.x installed
#our $DATABASE = [ 
#    'localhost',    # hostname or ip
#    5432,           # port
#    'irssi',        # user
#    'irssi',        # password
#    'postgres'         # database
#];
our $DATABASE = [ '192.168.18.1', 5432, 'mylog','mylog1234','mylog' ];
our $NETWORKS = [
    [
        # Network Name
        'MAGnet',
        # Nick       Username  IRCName / whois comment
        [ 'imMutebot', 'imMute', 'imMute\'s faithful logging bot', ],
        # Server host/ip,  port
        [ 'irc.perl.org', 6667 ],
        # Default Channels
        [ '#bots', ], #'#perl','#poe' 
    ],
    #[
    #    'FreeNode',
    #    [ 'imMutebot', 'imMute', 'imMute\'s faithful logging bot', ],
    #    [ [ 'irc.freenode.org', 6667 ] ],
    #    [ '#perl','#irssi','#ubuntu','##networking','#sparkfun','#httpd','##electronics' ],
    #],
];
our $DEBUG_LEVEL = 7;
#############################
use strict;
use lib './lib';
use POE;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::Connector;
use POE::Component::IRC::Plugin::BotCommand;
use POE::Component::IRC::Plugin::AutoJoin;
use POE::Component::Generic;
use DBI;
use DBD::Pg;
use POE::Component::Client::DNS;
use Data::Dumper;
use MyInserter;
use PCILogger;

main();
exit(0);
#############################
sub DEBUG (@) { if ( shift(@_) <= $::DEBUG_LEVEL ) { print join "\n", @_; print "\n"; } }
sub main {
    DEBUG 1, "Starting MyLog";
    
    # Setup each Network
    my $resolver = POE::Component::Client::DNS->spawn( Alias => 'resolver' );
    DEBUG 3, "Setting up networks";
    foreach my $nconf ( @$NETWORKS ){
        DEBUG 5, "Setting up network '".$nconf->[0]."'";
        DEBUG 7, "  Nick: $nconf->[1]->[0]","  Username: $nconf->[1]->[1]","  Ircname: $nconf->[1]->[2]";
        my $inserter = POE::Component::Generic->spawn(
            alias       => 'pcg_'.$nconf->[0],
            alt_fork    => 0,
            debug       => ( $DEBUG_LEVEL > 7 ? 1 : 0),
            verbose     => ( $DEBUG_LEVEL > 5 ? 1 : 0),
            package     => 'MyInserter',
            methods     => [qw[ init connected join kick mode nick part public quit topic ]],
        );
        $inserter->init({}, $DATABASE );
        my $pci = POE::Component::IRC::State->spawn(
            alias       => 'pci_'.$nconf->[0],
            Nick        => $nconf->[1]->[0],
            Username    => $nconf->[1]->[1],
            Ircname     => $nconf->[1]->[2],
            Resolver    => $resolver,
            plugin_debug => 0,
            Server      => $nconf->[2]->[0],
            Port        => $nconf->[2]->[1],
            
            socks_proxy => '127.0.0.1',
            socks_port => 1337,
        );
        $pci->plugin_add( 'Connector' => POE::Component::IRC::Plugin::Connector->new(
            delay => 150, reconnect => 40,
        ) );
        $pci->plugin_add( 'AutoJoin' => POE::Component::IRC::Plugin::AutoJoin->new(
            Channels => { map { $_ => '' } @{ $nconf->[3] } },
            RejoinOnKick => 1, Rejoin_delay => 10,
        ) );
        #$pci->plugin_add( 'BotCmd' => POE::Component::IRC::Plugin::BotCommand->new(
        #    Commands => {
        #    },
        #    in_channels => 0,
        #    in_private => 1,
        #    Ignore_unknown => 1,
        #) );
        $pci->plugin_add( 'MyLogger' => PCILogger->new($nconf->[0],$inserter) );
        $pci->yield( 'connect' => {});
    }
    DEBUG 1, "Starting POE Kernel!";
    POE::Kernel->run();
}
