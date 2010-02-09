package PCILogger;
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

1;