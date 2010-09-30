#!/usr/bin/perl
use strict;
use lib './lib';
use Data::Dumper;
use MyInserter;

my $ins = MyInserter->new();
$ins->init(['127.0.0.1',5432,'mylog','mylog1234','mylog']);
my ($self, $network, $nick, $ident, $host, $channel) = @_;
$ins->join('testnetwork','testnick','testident','testhost.example','#testchannel');
