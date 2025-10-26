package main

import (
	"strings"
	"testing"
)

func TestGreeterGreet(t *testing.T) {
	greeter := NewGreeter("World")
	result := greeter.Greet()

	if !strings.Contains(result, "World") {
		t.Errorf("Expected greeting to contain 'World', got: %s", result)
	}

	if !strings.Contains(result, "Builder") {
		t.Errorf("Expected greeting to contain 'Builder', got: %s", result)
	}
}

func TestGreeterFormalGreet(t *testing.T) {
	greeter := NewGreeter("Gopher")
	result := greeter.FormalGreet()

	if !strings.Contains(result, "Gopher") {
		t.Errorf("Expected formal greeting to contain 'Gopher', got: %s", result)
	}

	if !strings.Contains(result, "Welcome") {
		t.Errorf("Expected formal greeting to contain 'Welcome', got: %s", result)
	}
}

func TestProcessNames(t *testing.T) {
	names := []string{"alice", "bob", "", "charlie"}
	result := ProcessNames(names)

	expected := 3 // Empty string should be filtered
	if len(result) != expected {
		t.Errorf("Expected %d names, got %d", expected, len(result))
	}

	// All should be uppercase
	for _, name := range result {
		if name != strings.ToUpper(name) {
			t.Errorf("Expected uppercase name, got: %s", name)
		}
	}
}

func TestMapExample(t *testing.T) {
	result := MapExample()

	if result["go"] != 2 {
		t.Errorf("Expected 'go' count to be 2, got %d", result["go"])
	}

	if result["build"] != 1 {
		t.Errorf("Expected 'build' count to be 1, got %d", result["build"])
	}

	if result["test"] != 1 {
		t.Errorf("Expected 'test' count to be 1, got %d", result["test"])
	}
}

// Benchmark example
func BenchmarkGreet(b *testing.B) {
	greeter := NewGreeter("Benchmark")

	for i := 0; i < b.N; i++ {
		_ = greeter.Greet()
	}
}

func BenchmarkProcessNames(b *testing.B) {
	names := []string{"alice", "bob", "charlie", "dave", "eve"}

	for i := 0; i < b.N; i++ {
		_ = ProcessNames(names)
	}
}
