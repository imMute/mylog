# $Id: irssi-mylog.pl 143 2010-02-04 01:34:21Z immute $
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = ( q$Rev: 143 $ =~ /(\d+)/ )[0];
%IRSSI = (
  authors     => 'Matt "imMute" Sickler',
  contact     => 'imMute {at} mail.msk4.com',
  name        => 'MyLog',
  description => 'Logs channel/privmsg activity to a MySQL database',
  license     => 'GPLv2',
  url         => '',
  changed     => '$Date: 2010-02-04 01:34:21 +0000 (Thu, 04 Feb 2010) $',
);

=pod Description
Logs channel/privmsg activity to a MySQL database
=cut

=pod Useage
Initial:
- Run the included mylog-schema.sql (version 1.9) to load the new schema. ( Remeber to change the USE at the top to the name of your db. )
- /set mylog_db_host <your db host or ip>
- /set mylog_db_port <your db port>
- /set mylog_db_user <your db user>
- /set mylog_db_pass <your db pass>
- /set mylog_db_base <database to use>  # the user must have SELECT and INSERT permissions here
- /script load mylog

Other commands/settings:
bool: mylog_logging = toggle logging
cmd: mylog_reconnect = reconnect to the DB if the connection is lost
cmd: mylog_qst = re-prepare() the $sth vars.  should never need to use this though
=cut

use Irssi::Irc;
use Irssi qw/settings_add_str settings_get_str printformat settings_add_bool settings_get_bool settings_add_int settings_get_int/;
use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Sortkeys=1;
use DBI;

sub DEBUG (@) { 1 and printformat(MSGLEVEL_CRAP, 'mylog_debug', @_); }

Irssi::theme_register([
    'mylog_debug',         '%P>>%n %_MyLog(DEBUG):%_ $0-',
    'mylog_db_connected',  '%P>>%n %_MyLog:%_ Connected to db ($0:$1 - $2)',
    'mylog_db_no_connect', '%P>>%n %_MyLog:%_ Could not connect to database: $0',
    'mylog_no_setting',    '%P>>%n %_MyLog:%_ You did not specify the $0 setting (mylog_$1)',
    'mylog_loaded',        '%P>>%n %_MyLog:%_ MySQL-Log r$0 loaded',
    'mylog_error',         '%P>>%n %_MyLog:%_ %R%_Error%_ ($0):%n $1-',
]);

settings_add_str "mylog", "mylog_db_host",  "localhost";
settings_add_str "mylog", "mylog_db_port",  "3306";
settings_add_str "mylog", "mylog_db_user",  "irssi";
settings_add_str "mylog", "mylog_db_pass",  "irssi";
settings_add_str "mylog", "mylog_db_base",  "irssi";
settings_add_bool "mylog","mylog_logging",  1;
settings_add_int "mylog", "mylog_ping",     1000;

my $sth_prepare = {
  get_user_id   => q!SELECT `id` FROM `user_id` WHERE `nick` = ? AND `ident` = ? AND `host` = ?!,
  set_user_id   => q!INSERT INTO `user_id` VALUES(NULL, '0', ?, ?, ?)!,
  
  get_chan_id   => q!SELECT `id` FROM `channels` WHERE `channel` = ? AND `network` = ?!,
  set_chan_id   => q!INSERT INTO `channels` VALUES(NULL, ?, ?)!,
  
  get_reason_id => q!SELECT `id` FROM `reasons` WHERE `reason` = ?!,
  set_reason_id => q!INSERT INTO `reasons` VALUES(NULL, ?)!,
  
  insert_msg    => q!INSERT INTO `messages` VALUES(NULL, NOW(), ?, ?, ?)!,
  insert_pm     => q!INSERT INTO `pms` VALUES(NULL, NOW(), ?, ?, ?)!,
  insert_join   => q!INSERT INTO `joins` VALUES(NULL, NOW(), ?, ?)!,
  insert_quit   => q!INSERT INTO `quits` VALUES(NULL, NOW(), ?, ?)!,
  insert_part   => q!INSERT INTO `parts` VALUES(NULL, NOW(), ?, ?, ?)!,
  insert_topic  => q!INSERT INTO `topics` VALUES(NULL, NOW(), ?, ?, ?)!,
  insert_kick   => q!INSERT INTO `kicks` VALUES(NULL, NOW(), ?, ?, ?, ?)!,
  insert_nick   => q!INSERT INTO `nick_changes` VALUES(NULL, NOW(), ?, ?)!,
};
our $dbh;
my $sth = { };

sub dbi_connect {
    my $host = settings_get_str 'mylog_db_host';
    my $port = settings_get_str 'mylog_db_port';
    my $user = settings_get_str 'mylog_db_user';
    my $pass = settings_get_str 'mylog_db_pass';
    my $base = settings_get_str 'mylog_db_base';
    eval {
      $dbh = DBI->connect("DBI:mysql:database=$base;host=$host;port=$port", $user, $pass,
        { PrintError => 0, RaiseError => 1, }) or die;
    };
    if ($@) {
        printformat(MSGLEVEL_CRAP,'mylog_error', 'connect', $DBI::errstr);
        $dbh = $sth = undef;
        return 0;
    } else {
        printformat(MSGLEVEL_CRAP,'mylog_db_connected', $host, $port, $base);
        return setup_sth();
    }
}
sub setup_sth {
    return unless defined $dbh;
    while( my ($name, $sql) = each %$sth_prepare ){
        eval { $sth->{$name} = $dbh->prepare( $sql ) or die; };
        if ( $@ ){
            printformat(MSGLEVEL_CRAP, 'mylog_error', 'prepare', $!);
            $sth->{$name} = undef;
            return 0;
        }
    }
    return 1;
}

Irssi::command_bind("mylog_reconnect", 'dbi_connect');
Irssi::command_bind("mylog_qst", 'setup_sth');
Irssi::signal_add("setup changed", 'setup_ping_timer');

dbi_connect() if settings_get_bool("mylog_logging");
setup_ping_timer();
printformat(MSGLEVEL_CRAP, 'mylog_loaded', $VERSION);

{ #db connection ping/timer stuff
my $timer_id;
my $fail_count;
sub setup_ping_timer {
    Irssi::timeout_remove( $timer_id );
    $timer_id = Irssi::timeout_add(
        settings_get_int("mylog_ping"),
        \&ping_timer,
        undef
    );
}
sub ping_timer {
    return if $fail_count >= 5;
    unless ( defined $dbh and $dbi->ping() ){
        if ( dbi_connect() ){
            $fail_count = 0;
        } else {
            $fail_count++;
        }
    }
}
}

sub signal_add {
    my ($name, $sub) = @_;
    Irssi::signal_add( $name, sub {
        return unless settings_get_bool("mylog_logging");
        eval {
          $sub->(@_);
        };
        if ($@) { printformat(MSGLEVEL_CRAP, 'mylog_error', 'exec', $@); }
    });
}

sub sql {
    my ($name, @vars) = @_;
    my $S = $sth->{$name};
    my $rv = $S->execute( @vars );
    if ( $sth_prepare->{$name} =~ /^INSERT/ ){ # still hackery
        return $rv;
    } else {
        return $S->fetchall_arrayref();
    }
}
sub LID () { return $dbh->last_insert_id(undef, undef, undef, undef); }

{ # signal handlers
# --- Message

#  "message public",      SERVER_REC, char *msg, char *nick,   char *address, char *target
signal_add "message public", sub {
    my ($server, $msg, $nick, $address, $channel) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $user_id = m_user_id( $nick, $ident, $host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    
    sql('insert_msg', $user_id, $channel_id, $msg);
};

#  "message own_public",  SERVER_REC, char *msg, char *target
signal_add "message own_public", sub {
    my ($server, $message, $channel) = @_;
    
    my ($ident, $host) = split /@/, $server->{userhost}, 2;
    my $user_id = m_user_id( $server->{nick}, $ident, $host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    
    sql('insert_msg', $user_id, $channel_id, $message);
};

#  "message private",     SERVER_REC, char *msg, char *nick,   char *address
signal_add "message private", sub {
    my ($server, $message, $nick, $address) = @_;
};

#  "message own_private", SERVER_REC, char *msg, char *target, char *orig_target
signal_add "message own_private", sub {
    my ($server, $message, $target, $orig_target) = @_;
};

#  "message irc action",  SERVER_REC, char *msg, char *nick, char *address, char *target
signal_add "message irc action", sub { #TODO: finish
    my ($server, $msg, $nick, $address, $target) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    
    if ( $server->ischannel($target) ){
        my $user_id = m_user_id( $nick, $ident, $host );
        my $channel_id = m_chan( $target, $server->{chatnet} );
        sql('insert_msg', $user_id, $channel_id, "/me ".$msg);
    } else {
        # in PM. do nothing
    }
};

#  "message irc own_action", SERVER_REC, char *msg, char *target
signal_add "message irc own_action", sub { #TODO: finish
    my ($server, $msg, $target) = @_;
    
    my ($ident, $host) = split /@/, $server->{userhost}, 2;
    
    if ( $server->ischannel($target) ){
        my $user_id = m_user_id( $server->{nick}, $ident, $host );
        my $channel_id = m_chan( $target, $server->{chatnet} );
        sql('insert_msg', $user_id, $channel_id, "/me ".$msg);
    } else {
        # in PM. do nothing
    }
};

# --- Chan
#  "message join",     SERVER_REC, char *channel, char *nick,    char *address
signal_add "message join", sub {
    my ($server, $channel, $nick, $address) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $user_id = m_user_id( $nick, $ident, $host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    
    sql('insert_join', $user_id, $channel_id);
};

#  "message part",     SERVER_REC, char *channel, char *nick,    char *address, char *reason
signal_add "message part", sub {
    my ($server, $channel, $nick, $address, $reason) = @_;

    my ($ident, $host) = split /@/, $address, 2;
    my $user_id = m_user_id( $nick, $ident, $host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    my $quitmsg_id = m_reason( $reason );
    
    sql('insert_part', $user_id, $channel_id, $quitmsg_id);
};

#  "message quit",     SERVER_REC, char *nick,    char *address, char *reason
signal_add "message quit", sub {
    my ($server, $nick, $address, $reason) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $user_id = m_user_id( $nick, $ident, $host );
    
    my $quitmsg_id = m_reason( $reason );
    
    sql('insert_quit', $user_id, $quitmsg_id);
};

#  "message kick",     SERVER_REC, char *channel, char *nick,    char *kicker,  char *address, char *reason
signal_add "message kick", sub {
    my ($server, $channel, $kicked_nick, $kicker_nick, $kicker_address, $reason) = @_;
    
    my ($kicker_ident, $kicker_host) = split /@/, $kicker_address, 2;
    my $kicker_user_id = m_user_id( $kicker_nick, $kicker_ident, $kicker_host );
    
    my $kicked_address;
    eval { $kicked_address = $server->channel_find( $channel )->nick_find( $kicked_nick )->{host}; };
    return if $@;
    my ($kicked_ident, $kicked_host) = split /@/, $kicked_address, 2; # EH?
    my $kicked_user_id = m_user_id( $kicked_nick, $kicked_ident, $kicked_host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    my $reason_id = m_reason( $reason );
    
    sql('insert_kick', $kicked_user_id, $kicker_user_id, $channel_id, $reason_id );
};

#  "message nick",     SERVER_REC, char *newnick, char *oldnick, char *address
signal_add "message nick", sub {
    my ($server, $newnick, $oldnick, $address) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $old_user_id = m_user_id( $oldnick, $ident, $host );
    my $new_user_id = m_user_id( $newnick, $ident, $host );
    
    sql('insert_nick', $old_user_id, $new_user_id);
};

#  "message own_nick", SERVER_REC, char *newnick, char *oldnick, char *address
signal_add "message own_nick", sub {
    my ($server, $newnick, $oldnick, $address) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $old_user_id = m_user_id( $oldnick, $ident, $host );
    my $new_user_id = m_user_id( $newnick, $ident, $host );
    
    sql('insert_nick', $old_user_id, $new_user_id);
};

#  "message topic", SERVER_REC, char *channel, char *topic, char *nick, char *address
signal_add "message topic", sub {
    my ($server, $channel, $topic, $nick, $address) = @_;
    
    my ($ident, $host) = split /@/, $address, 2;
    my $user_id = m_user_id( $nick, $ident, $host );
    
    my $channel_id = m_chan( $channel, $server->{chatnet} );
    
    sql('insert_topic', $channel_id, $user_id, $topic);
}

# --- Notice
#  "message irc notice", SERVER_REC, char *msg, char *nick, char *address, char *target

#  "message irc own_notice", SERVER_REC, char *msg, char *target

# --- CTCP
#  "message irc ctcp", SERVER_REC, char *cmd, char *data, char *nick, char *address, char *target

#  "message irc own_ctcp", SERVER_REC, char *cmd, char *data, char *target

#  "ctcp reply", SERVER_REC, char *args, char *nick, char *addr, char *target


}

{ # relational helpers
sub m_sql {
    my ($name, @args) = @_;
    my $R = sql("get_$name", @args)->[0];
    #print Dumper($R);
    if (ref $R) { return $R->[0];}
    else        { sql("set_$name", @args); return LID(); }
}

sub m_user_id ($$$) {
    my ($nick, $ident, $host) = @_;
    return m_sql('user_id', $nick, $ident, $host);
}

sub m_chan ($$) {
    my ($chan, $net) = @_;
    return m_sql('chan_id', $chan, $net);
}

sub m_reason ($) {
    my ($reason) = @_;
    return m_sql('reason_id', $reason);
}

}
