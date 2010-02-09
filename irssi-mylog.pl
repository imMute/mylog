use strict;
use vars qw($VERSION %IRSSI);

$VERSION = 3001;
%IRSSI = (
  authors     => 'Matt "imMute" Sickler',
  contact     => 'imMute {at} mail.msk4.com',
  name        => 'MyLog',
  description => 'Logs channel/privmsg activity to a PostgreSQL database',
  license     => 'GPLv2',
  url         => '',
  changed     => '',
);

=pod Description
Logs channel/privmsg activity to a PostgreSQL database
=cut

=pod Useage
Initial:
- Run the included mylog-schema.sql (version 3.1) to load the new schema.
- /set mylog_db_host <your db host or ip>
- /set mylog_db_port <your db port>
- /set mylog_db_user <your db user>
- /set mylog_db_pass <your db pass>
- /set mylog_db_base <database to use>
- /script load mylog

Other commands/settings:
bool: mylog_logging = toggle logging
cmd: mylog_reconnect = reconnect to the DB if the connection is lost
cmd: mylog_qst = re-prepare() the $sth vars.  should never need to use this though
=cut

use Irssi::Irc;
use Irssi qw/settings_add_str settings_get_str printformat settings_add_bool settings_get_bool settings_add_int settings_get_int/;
use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Sortkeys=1;
sub DEBUG (@) { 1 and printformat(MSGLEVEL_CRAP, 'mylog_debug', @_); }
use POE;
use POE::Component::Generic;

Irssi::theme_register([
    'mylog_debug',         '%P>>%n %_MyLog(DEBUG):%_ $0-',
    'mylog_db_connected',  '%P>>%n %_MyLog:%_ Connected to db ($0:$1 - $2)',
    'mylog_db_no_connect', '%P>>%n %_MyLog:%_ Could not connect to database: $0',
    'mylog_no_setting',    '%P>>%n %_MyLog:%_ You did not specify the $0 setting (mylog_$1)',
    'mylog_loaded',        '%P>>%n %_MyLog:%_ MySQL-Log r$0 loaded',
    'mylog_error',         '%P>>%n %_MyLog:%_ %R%_Error%_ ($0):%n $1-',
]);

settings_add_str "mylog", "mylog_db_host",  "localhost";
settings_add_str "mylog", "mylog_db_port",  "5432";
settings_add_str "mylog", "mylog_db_user",  "irssi";
settings_add_str "mylog", "mylog_db_pass",  "irssi";
settings_add_str "mylog", "mylog_db_base",  "mylog";
settings_add_bool "mylog","mylog_logging",  0;
settings_add_int "mylog", "mylog_ping",     1000;

my $inserter;

sub setup_inserter {
    my $inserter = POE::Component::Generic->new(
        alias       => 'pcg_inserter',
        alt_fork    => 0,
        package     => 'MyInserter',
        methods     => [qw[ init connected join kick mode nick part public quit topic ]],
    );
    $inserter->init({}, "mylog" );
}

Irssi::command_bind("mylog_reconnect", 'setup_inserter');

dbi_connect() if settings_get_bool("mylog_logging");
printformat(MSGLEVEL_CRAP, 'mylog_loaded', $VERSION);

sub signal_add {
    my ($name, $sub) = @_;
    Irssi::signal_add( $name, sub {
        return unless settings_get_bool("mylog_logging");
        return unless ref $inserter;
        eval {
          $sub->(@_);
        };
        if ($@) { printformat(MSGLEVEL_CRAP, 'mylog_error', 'exec', $@); }
    });
}

{ # signal handlers
# --- Message

#  "message public",      SERVER_REC, char *msg, char *nick,   char *address, char *target
signal_add "message public", sub {
    my ($server, $msg, $nick, $address, $channel) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->public({}, $server->{chatnet}, $nick, $ident, $host, $channel, $msg );
};

#  "message own_public",  SERVER_REC, char *msg, char *target
signal_add "message own_public", sub {
    my ($server, $msg, $channel) = @_;
    my ($ident, $host) = split /@/, $server->{userhost}, 2;
    $inserter->public({}, $server->{chatnet}, $server->{nick}, $ident, $host, $channel, $msg );
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
        $inserter->public({}, $server->{chatnet}, $nick, $ident, $host, $target, "/me ".$msg );
    } else {
        # in PM. do nothing
    }
};

#  "message irc own_action", SERVER_REC, char *msg, char *target
signal_add "message irc own_action", sub { #TODO: finish
    my ($server, $msg, $target) = @_;
    
    my ($ident, $host) = split /@/, $server->{userhost}, 2;
    
    if ( $server->ischannel($target) ){
        $inserter->public({}, $server->{chatnet}, $server->{nick}, $ident, $host, $target, "/me ".$msg );
    } else {
        # in PM. do nothing
    }
};

# --- Chan
#  "message join",     SERVER_REC, char *channel, char *nick,    char *address
signal_add "message join", sub {
    my ($server, $channel, $nick, $address) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->join({}, $server->{chatnet},$nick,$ident,$host,$channel);
};

#  "message part",     SERVER_REC, char *channel, char *nick,    char *address, char *reason
signal_add "message part", sub {
    my ($server, $channel, $nick, $address, $reason) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->part({}, $self->{chatnet},$nick,$ident,$host,$channel,$reason);
};

#  "message quit",     SERVER_REC, char *nick,    char *address, char *reason
signal_add "message quit", sub {
    my ($server, $nick, $address, $reason) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->quit({}, $self->{chatnet},$nick,$ident,$host,$reason);
};

#  "message kick",     SERVER_REC, char *channel, char *nick,    char *kicker,  char *address, char *reason
signal_add "message kick", sub {
    my ($server, $channel, $kicked_nick, $kicker_nick, $kicker_address, $reason) = @_;
    
    my ($kicker_ident, $kicker_host) = split /@/, $kicker_address, 2;
    
    my $kicked_address;
    eval { $kicked_address = $server->channel_find( $channel )->nick_find( $kicked_nick )->{host}; };
    return if $@;
    
    my ($kicked_ident, $kicked_host) = split /@/, $kicked_address, 2;
    
    $inserter->kick({}, $self->{chatnet},$kicked_nick,$kicked_ident,$kicked_host,$kicker_nick,$kicker_ident,$kicker_host,$channel,$reason);
};

#  "message nick",     SERVER_REC, char *newnick, char *oldnick, char *address
signal_add "message nick", sub {
    my ($server, $newnick, $oldnick, $address) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->nick({}, $self->{chatnet},$oldnick,$newnick,$ident,$host);
};

#  "message own_nick", SERVER_REC, char *newnick, char *oldnick, char *address
signal_add "message own_nick", sub {
    my ($server, $newnick, $oldnick, $address) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->nick({}, $self->{chatnet},$oldnick,$newnick,$ident,$host);
};

#  "message topic", SERVER_REC, char *channel, char *topic, char *nick, char *address
signal_add "message topic", sub {
    my ($server, $channel, $topic, $nick, $address) = @_;
    my ($ident, $host) = split /@/, $address, 2;
    $inserter->topic({}, $self->{chatnet},$nick,$ident,$host,$channel,$topic);
}

# --- Notice
#  "message irc notice", SERVER_REC, char *msg, char *nick, char *address, char *target

#  "message irc own_notice", SERVER_REC, char *msg, char *target

# --- CTCP
#  "message irc ctcp", SERVER_REC, char *cmd, char *data, char *nick, char *address, char *target

#  "message irc own_ctcp", SERVER_REC, char *cmd, char *data, char *target

#  "ctcp reply", SERVER_REC, char *args, char *nick, char *addr, char *target


}
