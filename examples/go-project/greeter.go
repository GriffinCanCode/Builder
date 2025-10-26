package main

import "fmt"

// Greeter provides greeting functionality
type Greeter struct {
	name string
}

// NewGreeter creates a new Greeter
func NewGreeter(name string) *Greeter {
	return &Greeter{name: name}
}

// Greet returns a greeting message
func (g *Greeter) Greet() string {
	return fmt.Sprintf("Hello from Builder, %s!", g.name)
}

// FormalGreet returns a formal greeting
func (g *Greeter) FormalGreet() string {
	return fmt.Sprintf("Good day, %s. Welcome to Builder.", g.name)
}
