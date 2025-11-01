#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;

use Greeter;

# Test object creation
my $greeter = Greeter->new(name => 'Test');
isa_ok($greeter, 'Greeter', 'Created greeter object');

# Test greet method
my $greeting = $greeter->greet();
ok(defined $greeting, 'greet() returns a value');
is($greeting, 'Hello, Test!', 'greet() returns correct greeting');

# Test farewell method
my $farewell = $greeter->farewell();
ok(defined $farewell, 'farewell() returns a value');
is($farewell, 'Goodbye, Test!', 'farewell() returns correct farewell');

