import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import std.string;

void main()
{
    writeln("=== Builder D Example ===\n");
    
    // Show off D's features
    writeln("D Language Features:");
    
    // Ranges
    auto numbers = iota(1, 6);
    auto doubled = numbers.map!(x => x * 2);
    writeln("  Doubled numbers: ", doubled.array);
    
    // UFCS (Uniform Function Call Syntax)
    auto text = "hello builder";
    writeln("  Uppercase: ", text.toUpper);
    
    // Templates
    writeln("  Max(10, 20): ", max(10, 20));
    
    // Compile-time evaluation
    enum factorial5 = factorial(5);
    writeln("  5! (compile-time): ", factorial5);
}

// Compile-time factorial
int factorial(int n)
{
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

