#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

# Simple Perl script demonstrating Builder's Perl support
use FindBin qw($Bin);
use lib "$Bin/lib";

use Greeter;

# Create a greeter
my $greeter = Greeter->new(name => 'Builder');

# Print greeting
say $greeter->greet();

# Print farewell
say $greeter->farewell();

exit 0;

