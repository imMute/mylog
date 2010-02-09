package MyInserter;
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
            network_id  => q!SELECT "id" FROM "networks" WHERE "network" = ?!,
            user_id     => q!SELECT "id" FROM "user_id"  WHERE "network_id" = ? AND "nick" = ? AND "ident" = ? AND "hostname" = ?!,
            channel_id  => q!SELECT "id" FROM "channels" WHERE "channel" = ?!,
            reason_id   => q!SELECT "id" FROM "reasons"  WHERE "reason" = ?!,
        },
        {},
        {
            network_id => "networks",
            user_id    => "user_id",
            channel_id => "channels",
            reason_id  => "reasons",
        },
        {
            network_id  => q!INSERT INTO "networks"      VALUES(DEFAULT, ?)!,
            user_id     => q!INSERT INTO "user_id"       VALUES(DEFAULT, ?, ?, ?, ?)!,
            channel_id  => q!INSERT INTO "channels"      VALUES(DEFAULT, ?)!,
            reason_id   => q!INSERT INTO "reasons"       VALUES(DEFAULT, ?)!,
        },
        {},
        {
            insert_join   => q!INSERT INTO "joins"        VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_kick   => q!INSERT INTO "kicks"        VALUES(DEFAULT, NOW(), ?, ?, ?, ?, ?)!,
            insert_msg    => q!INSERT INTO "messages"     VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
            insert_pm     => q!INSERT INTO "pms"          VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_nick   => q!INSERT INTO "nick_changes" VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_part   => q!INSERT INTO "parts"        VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
            insert_quit   => q!INSERT INTO "quits"        VALUES(DEFAULT, NOW(), ?, ?, ?)!,
            insert_topic  => q!INSERT INTO "topics"       VALUES(DEFAULT, NOW(), ?, ?, ?, ?)!,
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
    
    $dbh->do('SET search_path = "mylog"');
    
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


1;