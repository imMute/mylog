#!/usr/bin/perl
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
use Config::General qw/ParseConfig/;
use Getopt::Long;
use Data::Dumper;
use YAML::Syck;
sub DEBUG (@) { if ( shift(@_) <= $::DEBUG_LEVEL ) { print join "\n", @_; print "\n"; } }

my $conf_filename;
my $DEBUG_LEVEL = 10;
my $quiet = 0;

GetOptions( "config=s" => \$conf_filename,
            "debug=i"  => \$DEBUG_LEVEL,
            "quiet"    => \$quiet );

my $config = LoadFile( $conf_filename );

# check config options 
defined $config->{Database}->{$_} or die "Database::$_ is a required option"
   for (qw/Type Host Port User Pass DB/);

defined $config->{$_} or die "$_ is a required option"
   for (qw/Nick Ident IRCName/);

# copy some "default" values around
foreach my $net ( keys %{ $config->{Networks} } ){
    $config->{Networks}->{$net}->{__name} = $net;
    $config->{Networks}->{$net}->{Nick}    ||= $config->{Nick};
    $config->{Networks}->{$net}->{Ident}   ||= $config->{Ident};
    $config->{Networks}->{$net}->{IRCName} ||= $config->{IRCName};
}

# Print the config for debugging
print STDERR Dumper( $config );

my $resolver = POE::Component::Client::DNS->spawn( Alias => 'resolver' );
foreach my $key ( keys %{ $config->{Networks} } ){
    create_network( $key, $config->{Networks}->{$key} );
}
DEBUG 1, "Starting POE Kernel!";
POE::Kernel->run();

sub create_network {
    my ($name, $nconf) = @_;
    DEBUG 5, "Setting up network '".$name."'";
    DEBUG 7, "  Nick: $nconf->{Nick}","  Ident: $nconf-{Ident}","  Ircname: $nconf->{IRCName}";
    
    my $inserter = create_inserter( $name, $nconf );
    
    my $pci = POE::Component::IRC::State->spawn(
        alias       => 'pci_'.$name,
        Nick        => $nconf->{Nick},
        Username    => $nconf->{Ident},
        Ircname     => $nconf->{IRCName},
        Resolver    => $resolver,
        plugin_debug => 0,
        Server      => $nconf->{Host},
        Port        => $nconf->{Port} || 6667,
    );
    $pci->plugin_add( 'Connector' => POE::Component::IRC::Plugin::Connector->new(
        delay => 150, reconnect => 40,
    ) );
    $pci->plugin_add( 'AutoJoin' => POE::Component::IRC::Plugin::AutoJoin->new(
        Channels => { map { $_ => '' } @{ $nconf->{AutoJoinChannels} } },
        RejoinOnKick => 1, Rejoin_delay => 10,
    ) );
    #$pci->plugin_add( 'BotCmd' => POE::Component::IRC::Plugin::BotCommand->new(
    #    Commands => {
    #    },
    #    in_channels => 0,
    #    in_private => 1,
    #    Ignore_unknown => 1,
    #) );
    $pci->plugin_add( 'MyLogger' => PCILogger->new($name,$inserter) );
    #$pci->yield( 'connect' => {});
}

sub create_inserter {
    my ($name, $nconf) = @_;
    
    my $inserter = POE::Component::Generic->spawn(
        alias       => 'pcg_'.$name,
        alt_fork    => 0,
        debug       => ( $DEBUG_LEVEL > 7 ? 1 : 0),
        verbose     => ( $DEBUG_LEVEL > 5 ? 1 : 0),
        package     => 'MyInserter',
        methods     => [qw[ init connected join kick mode nick part public quit topic ]],
    );
    $inserter->init({}, $config->{Database} );
    
    return $inserter;
}