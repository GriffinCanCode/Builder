package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("=== Builder Go Example ===\n")

	greeter := NewGreeter("Gopher")

	fmt.Println("Greetings:")
	fmt.Println(" ", greeter.Greet())
	fmt.Println(" ", greeter.FormalGreet())

	fmt.Println("\nSystem Info:")
	fmt.Println("  Time:", time.Now().Format(time.RFC3339))
	fmt.Println("  Built with: Builder")
}
