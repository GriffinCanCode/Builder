package main

import (
	"fmt"
	"strings"
)

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

// ProcessNames demonstrates slice operations (common use case)
func ProcessNames(names []string) []string {
	processed := make([]string, 0, len(names))
	for _, name := range names {
		if name != "" {
			processed = append(processed, strings.ToUpper(name))
		}
	}
	return processed
}

// MapExample demonstrates map usage (common use case)
func MapExample() map[string]int {
	counts := make(map[string]int)
	words := []string{"go", "build", "go", "test"}
	for _, word := range words {
		counts[word]++
	}
	return counts
}
