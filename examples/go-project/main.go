package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// Config represents application configuration (common use case)
type Config struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	Debug   bool   `json:"debug"`
}

func main() {
	fmt.Println("=== Builder Go Example ===\n")

	greeter := NewGreeter("Gopher")

	fmt.Println("Greetings:")
	fmt.Println(" ", greeter.Greet())
	fmt.Println(" ", greeter.FormalGreet())

	// Configuration handling (common real-world use case)
	config := Config{
		Name:    "Builder",
		Version: "1.0.0",
		Debug:   false,
	}

	jsonData, err := json.Marshal(config)
	if err != nil {
		fmt.Println("Error marshaling config:", err)
		os.Exit(1)
	}

	fmt.Println("\nConfiguration:")
	fmt.Println("  JSON:", string(jsonData))

	// File operations and error handling (80/20 rule)
	fmt.Println("\nEnvironment:")
	fmt.Println("  HOME:", os.Getenv("HOME"))
	fmt.Println("  Args:", os.Args)

	fmt.Println("\nSystem Info:")
	fmt.Println("  Time:", time.Now().Format(time.RFC3339))
	fmt.Println("  Built with: Builder")

	// Goroutines and concurrency (important Go feature)
	done := make(chan bool)
	go func() {
		fmt.Println("\n[Goroutine] Running async task...")
		time.Sleep(10 * time.Millisecond)
		fmt.Println("[Goroutine] Task completed!")
		done <- true
	}()
	<-done
}
