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
        # Server host/ip,  port
        [ 'irc.perl.org', 6667 ],
        # Default Channels
        [ '#bots', '#perl','#poe' ],
    ],
    [
        'FreeNode',
        [ 'imMutebot', 'imMute', 'imMute\'s faithful logging bot', ],
        [ 'irc.freenode.org', 6667 ],
        [ '#perl','#irssi','#ubuntu','##networking','#sparkfun' ],
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
            Server      => $nconf->[2]->[0],
            plugin_debug => 0,
        );
        #$pci->plugin_add( 'Connector' => POE::Component::IRC::Plugin::Connector->new(
        #    delay => 150, reconnect => 40,
        #    # servers => [ ],
        #) );
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
    $self->[1]->nick({}, $self->[0],$oldnick,$newnick,$ident,$host);
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


package MyInserter;  # ----- Controller Routines -----
use DBI;
use DBD::Pg;
use Data::Dumper;
sub DEBUG (@) { print join "\n", @_; print "\n"; }
sub _DBH () { 0 }
sub _GETS () { 1 }
sub _GETP () { 2 }
sub _TBL  () { 3 }
sub _SETS () { 4 }
sub _SETP () { 5 }
sub _INSS () { 6 }
sub _INSP () { 7 }

sub new {
    my ($package) = @_;
    
    $Data::Dumper::Indent = 0;
    
    return bless [
        undef,
        {
            network_id  => q!SELECT "id" FROM "mylog"."networks" WHERE "network" = ?!,
            user_id     => q!SELECT "id" FROM "mylog"."user_id"  WHERE "network_id" = ? AND "nick" = ? AND "ident" = ? AND "hostname" = ?!,
            channel_id  => q!SELECT "id" FROM "mylog"."channels" WHERE "channel" = ?!,
            reason_id   => q!SELECT "id" FROM "mylog"."reasons"  WHERE "reason" = ?!,
        },
        {},
        {
            network_id => "networks",
            user_id    => "user_id",
            channel_id => "channels",
            reason_id  => "reasons",
        },
        {
            network_id  => q!INSERT INTO "mylog"."networks"      VALUES(DEFAULT, ?)!,
            user_id     => q!INSERT INTO "mylog"."user_id"       VALUES(DEFAULT, ?, ?, ?, ?)!,
            channel_id  => q!INSERT INTO "mylog"."channels"      VALUES(DEFAULT, ?)!,
            reason_id   => q!INSERT INTO "mylog"."reasons"       VALUES(DEFAULT, ?)!,
        },
        {},
        {
            insert_join   => q!INSERT INTO "mylog"."joins"        VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_kick   => q!INSERT INTO "mylog"."kicks"        VALUES(DEFAULT, NOW(), ?, ?, ?, ?, ?)!,
            insert_msg    => q!INSERT INTO "mylog"."messages"     VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
            insert_pm     => q!INSERT INTO "mylog"."pms"          VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_nick   => q!INSERT INTO "mylog"."nick_changes" VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_part   => q!INSERT INTO "mylog"."parts"        VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
            insert_quit   => q!INSERT INTO "mylog"."quits"        VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_topic  => q!INSERT INTO "mylog"."topics"       VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
        },
        {},
    ], $package;
}

sub init {
    my ($self) = shift;
    my ($host,$port,$user,$pass,$db) = @{ $_[0] };
    my $dbh = $self->[_DBH] = DBI->connect(
        "dbi:Pg:dbname=$db;host=$host;port=$port",
        $user,
        $pass,
        {
            AutoCommit => 1,
            PrintWarn => 1,
            PrintError => 1,
            RaiseError => 1,
        },
    ) or die "Could not spawn DBI connection: $DBI::errstr";
    
    while ( my ($name, $sql) = each %{ $self->[_GETS] } ){
        $self->[_GETP]->{$name} = $dbh->prepare( $sql )
          or die "Could not prepare get statement '$name': $DBI::errstr";
    }
    while ( my ($name, $sql) = each %{ $self->[_SETS] } ){
        $self->[_SETP]->{$name} = $dbh->prepare( $sql )
          or die "Could not prepare set statement '$name': $DBI::errstr";
    }
    while ( my ($name, $sql) = each %{ $self->[_INSS] } ){
        $self->[_INSP]->{$name} = $dbh->prepare( $sql )
          or die "Could not prepare insert statement '$name': $DBI::errstr";
    }
    
    return 1;
}

sub s_get {
    my ($self, $name, @vars) = @_;
    DEBUG "s_get: ".Dumper([$name,@vars]);
    my $sth = $self->[_GETP]->{$name};
    $sth->execute( @vars );
    my $v = $sth->fetchall_arrayref();
    DEBUG "s_get return: ".Dumper($v);
    return $v;
}
sub s_set {
    my ($self, $name, @vars) = @_;
    DEBUG "s_set: ".Dumper([$name,@vars]);
    $self->[_SETP]->{$name}->execute( @vars );
    my $v = $self->[_DBH]->last_insert_id( undef, "mylog", $self->[_TBL]->{$name}, undef );
    DEBUG "s_set return: ".Dumper($v);
    return $v;
}
sub s_insert {
    my ($self, $name, @vars) = @_;
    DEBUG "s_insert: ".Dumper([$name,@vars]);
    $self->[_INSP]->{$name}->execute( @vars );
}

sub m_sql {
    my ($self, $name, @args) = @_;
    my $R = $self->s_get($name, @args)->[0];
    if (ref $R) {
        return $R->[0];
    } else {
        return $self->s_set($name, @args);
    }
}


sub connected {
    my ($self, $network, $name) = @_;
}

sub join {
    DEBUG "join:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $channel) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $user_id    = $self->m_sql( user_id => $network_id, $nick, $ident, $host );
    my $channel_id = $self->m_sql( channel_id => $channel );
    
    $self->s_insert( insert_join => $user_id, $network_id, $channel_id);
}

sub kick {
    DEBUG "kick:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $kicked_nick, $kicked_ident, $kicked_host, $kicker_nick, $kicker_ident, $kicker_host, $channel, $reason) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $kicked_id  = $self->m_sql( user_id => $network_id, $kicked_nick, $kicked_ident, $kicked_host );
    my $kicker_id  = $self->m_sql( user_id => $network_id, $kicker_nick, $kicker_ident, $kicker_host );
    my $channel_id = $self->m_sql( channel_id => $channel );
    my $reason_id  = $self->m_sql( reason_id  => $reason );
    
    $self->s_insert( insert_kick => $kicked_id, $kicker_id, $network_id, $channel_id, $reason_id );
}

sub mode {
    DEBUG "mode:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $channel) = @_;
}

sub nick {
    DEBUG "nick:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $old_nick, $new_nick, $ident, $host) = @_;
    
    my $network_id  = $self->m_sql( network_id => $network );
    my $old_user_id = $self->m_sql( user_id => $network_id, $old_nick, $ident, $host );
    my $new_user_id = $self->m_sql( user_id => $network_id, $new_nick, $ident, $host );
    
    $self->s_insert( insert_nick => $old_user_id, $new_user_id, $network_id );
}

sub part {
    DEBUG "part:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $channel, $reason) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $channel_id = $self->m_sql( channel_id => $channel );
    my $user_id    = $self->m_sql( user_id => $network_id, $nick, $ident, $host );
    my $reason_id  = $self->m_sql( reason_id => $reason );
    
    $self->s_insert( insert_part => $user_id, $network_id, $channel_id, $reason_id );
}

sub public {
    DEBUG "public:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $channel, $msg) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $user_id    = $self->m_sql( user_id => $network_id, $nick, $ident, $host );
    my $channel_id = $self->m_sql( channel_id => $channel );
    
    $self->s_insert( insert_msg => $user_id, $network_id, $channel_id, $msg);
}

sub quit {
    DEBUG "quit:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $reason) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $user_id    = $self->m_sql( user_id => $network_id, $nick, $ident, $host );
    my $reason_id  = $self->m_sql( reason_id => $reason );
    
    $self->s_insert( insert_quit => $user_id, $network_id, $reason_id );
}

sub topic {
    DEBUG "topic:  ".Dumper([@_[1..$#_]]);
    my ($self, $network, $nick, $ident, $host, $channel, $topic) = @_;
    
    my $network_id = $self->m_sql( network_id => $network );
    my $user_id    = $self->m_sql( user_id => $network_id, $nick, $ident, $host );
    my $channel_id = $self->m_sql( channel_id => $channel );
    
    $self->s_insert( insert_topic => $user_id, $network_id, $channel_id, $topic );
}
