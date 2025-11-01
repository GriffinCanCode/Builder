package Greeter;
use strict;
use warnings;
use v5.10;

=head1 NAME

Greeter - A simple greeting module

=head1 SYNOPSIS

    use Greeter;
    
    my $greeter = Greeter->new(name => 'World');
    say $greeter->greet();

=head1 DESCRIPTION

This module provides a simple greeter functionality for demonstrating
Perl support in the Builder build system.

=head1 METHODS

=head2 new

Constructor. Takes a hash with the following parameters:

=over 4

=item * name - The name to greet (required)

=back

=cut

sub new {
    my ($class, %args) = @_;
    
    die "name parameter is required" unless $args{name};
    
    my $self = {
        name => $args{name},
    };
    
    return bless $self, $class;
}

=head2 greet

Returns a greeting string.

=cut

sub greet {
    my ($self) = @_;
    return "Hello, " . $self->{name} . "!";
}

=head2 farewell

Returns a farewell string.

=cut

sub farewell {
    my ($self) = @_;
    return "Goodbye, " . $self->{name} . "!";
}

=head1 AUTHOR

Builder Team

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;

