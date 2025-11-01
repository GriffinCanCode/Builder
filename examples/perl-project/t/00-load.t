#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok('Greeter') || print "Bail out!\n";
}

diag("Testing Greeter module");

