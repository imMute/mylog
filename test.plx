#!/usr/bin/perl
use strict;
use lib './lib';
use Data::Dumper;
use MyInserter;

my $ins = MyInserter->new();
$ins->init(['192.168.18.1',5432,'mylogadmin','irssi','mylog']);

