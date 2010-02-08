#!/usr/bin/perl
#####   CONFIGURATION   #####
# Database must have schema version 3.1.x installed
our $DATABASE = [ 
    'localhost',    # hostname or ip
    5432,           # port
    'irssi',        # user
    'irssi',        # password
    'postgres'         # database
];
#$DATABASE = [ '192.168.18.1', 5432, 'irssi','irssi','postgres' ];
our $NETWORKS = [
    [
        # Network Name
        'MAGnet',
        # Nick       Username  IRCName / whois comment
        [ 'imMutebot', 'imMute', 'imMute\'s faithful logging bot', ],
        # Array of  Server host/ip,  port
        [
            [ 'irc.perl.org', 6667 ],
        ]
        # Default Channels
        [ '#bots', '#perl','#poe' ],
    ],
    [
        'FreeNode',
        [ 'imMutebot', 'imMute', 'imMute\'s faithful logging bot', ],
        [ [ 'irc.freenode.org', 6667 ] ],
        [ '#perl','#irssi','#ubuntu','##networking','#sparkfun','#httpd','##electronics' ],
    ],
];
our $DEBUG_LEVEL = 9;
#############################
use strict;
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
            debug       => 1,
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
        );
        $pci->plugin_add( 'Connector' => POE::Component::IRC::Plugin::Connector->new(
            delay => 150, reconnect => 40,
            servers => $nconf->[2]->[0],
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
        $pci->plugin_add( 'MyLogger' => MyLogger->new($nconf->[0],$inserter) );
        $pci->yield( 'connect' => {} );
    }
    
    DEBUG 1, "Starting POE Kernel!";
    POE::Kernel->run();
}

package MyLogger;  # ----- IRC Event Handlers -----
use POE::Component::IRC::Plugin qw( :ALL );
sub DEBUG (@) { if ( shift(@_) <= $::DEBUG_LEVEL ) { print join "\n", @_; print "\n"; } }
use Data::Dumper;

sub new {
    my ($package, $name, $inserter) = @_;
    return bless [
        $name,
        $inserter,
    ], $package;
}

sub PCI_register {
    my ($self, $irc) = @_;
    $irc->plugin_register( $self, 'SERVER', qw[
        connected
        join kick part quit
        mode nick topic
        public
    ]);
    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_connected {
    my ($self, $irc, $servername) = @_;
    DEBUG 10, $self->[0]."> CONNECTED ".Dumper([@_[2..$#_]]);
    
    $self->[1]->connected({}, $self->[0],$$servername);
    return PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc, $nickhost, $channel) = @_;
    DEBUG 10, $self->[0]."> JOIN ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->join({}, $self->[0],$nick,$ident,$host,$$channel);
    return PCI_EAT_NONE;
}

sub S_kick {
    my ($self, $irc, $kickernh, $channel, $kicked, $reason) = @_;
    DEBUG 10, $self->[0]."> KICK ".Dumper([@_[2..$#_]]);
    
    my $kickednh = $irc->nick_long_form( $$kicked );
    my ($kicked_nick,$kicked_ident,$kicked_host) = split /[!@]/, $kickednh;
    my ($kicker_nick,$kicker_ident,$kicker_host) = split /[!@]/, $$kickernh;
    $self->[1]->kick({}, $self->[0],$kicked_nick,$kicked_ident,$kicked_host,$kicker_nick,$kicker_ident,$kicker_host,$$channel,$$reason);
    return PCI_EAT_NONE;
}

sub S_mode {
    my ($self, $irc, $nickhost, $channel, $mode, @args) = @_;
    DEBUG 10, $self->[0]."> MODE ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->mode({}, $self->[0],$nick,$ident,$host,$$channel);
    return PCI_EAT_NONE;
}

sub S_nick {
    my ($self, $irc, $nickhost, $newnick) = @_;
    DEBUG 10, $self->[0]."> NICK ".Dumper([@_[2..$#_]]);
    
    my ($oldnick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->nick({}, $self->[0],$oldnick,$$newnick,$ident,$host);
    return PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc, $nickhost, $channel, $reason) = @_;
    DEBUG 10, $self->[0]."> PART ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->part({}, $self->[0],$nick,$ident,$host,$$channel,$$reason);
    return PCI_EAT_NONE;
}

sub S_public {
    my ($self, $irc, $nickhost, $channels, $message) = @_;
    DEBUG 10, $self->[0]."> PUBLIC ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    foreach my $channel ( @$$channels ){
        $self->[1]->public({}, $self->[0],$nick,$ident,$host,$channel,$$message);
    }
    return PCI_EAT_NONE;
}

sub S_quit {
    my ($self, $irc, $nickhost, $reason) = @_;
    DEBUG 10, $self->[0]."> QUIT ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->quit({}, $self->[0],$nick,$ident,$host,$$reason);
    return PCI_EAT_NONE;
}

sub S_topic {
    my ($self, $irc, $nickhost, $channel, $topic) = @_;
    DEBUG 10, $self->[0]."> TOPIC ".Dumper([@_[2..$#_]]);
    
    my ($nick,$ident,$host) = split /[!@]/, $$nickhost;
    $self->[1]->topic({}, $self->[0],$nick,$ident,$host,$$channel,$$topic);
    return PCI_EAT_NONE;
}
