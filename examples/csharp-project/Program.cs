// C# project demonstrating modern C# features
using System;
using System.Collections.Generic;
using System.Linq;

namespace BuilderExample
{
    // Record type (C# 9+)
    public record Person(string FirstName, string LastName, int Age);

    // Class example with modern features
    public class Calculator
    {
        // Property with init-only setter (C# 9+)
        public string Name { get; init; } = "Calculator";

        // Method with expression body
        public int Add(int a, int b) => a + b;

        public int Subtract(int a, int b) => a - b;

        public int Multiply(int a, int b) => a * b;

        public double Divide(int a, int b)
        {
            if (b == 0)
                throw new DivideByZeroException("Cannot divide by zero");
            return (double)a / b;
        }

        // Generic method
        public T GetMax<T>(T a, T b) where T : IComparable<T>
        {
            return a.CompareTo(b) > 0 ? a : b;
        }
    }

    // Static class for utilities
    public static class StringHelpers
    {
        public static string Reverse(string input)
        {
            char[] chars = input.ToCharArray();
            Array.Reverse(chars);
            return new string(chars);
        }

        public static bool IsPalindrome(string input)
        {
            string normalized = input.ToLower().Replace(" ", "");
            return normalized == Reverse(normalized);
        }
    }

    // Main program
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Builder C# Example ===\n");

            // String operations
            string message = "Hello from C#!";
            Console.WriteLine("String Operations:");
            Console.WriteLine($"  Original: {message}");
            Console.WriteLine($"  Uppercase: {message.ToUpper()}");
            Console.WriteLine($"  Length: {message.Length}");
            Console.WriteLine($"  Reversed: {StringHelpers.Reverse(message)}");

            // List operations (LINQ)
            var numbers = new List<int> { 1, 2, 3, 4, 5 };
            var doubled = numbers.Select(x => x * 2).ToList();

            Console.WriteLine("\nList Operations:");
            Console.WriteLine($"  Original: [{string.Join(", ", numbers)}]");
            Console.WriteLine($"  Doubled: [{string.Join(", ", doubled)}]");
            Console.WriteLine($"  Sum: {numbers.Sum()}");
            Console.WriteLine($"  Average: {numbers.Average()}");
            Console.WriteLine($"  Max: {numbers.Max()}");

            // Dictionary example
            var scores = new Dictionary<string, int>
            {
                ["Alice"] = 95,
                ["Bob"] = 87,
                ["Charlie"] = 92
            };

            Console.WriteLine("\nDictionary Example:");
            foreach (var (name, score) in scores)
            {
                Console.WriteLine($"  {name}: {score}");
            }

            // Calculator example
            var calc = new Calculator { Name = "MyCalculator" };
            Console.WriteLine($"\nCalculator ({calc.Name}):");
            Console.WriteLine($"  10 + 5 = {calc.Add(10, 5)}");
            Console.WriteLine($"  10 - 5 = {calc.Subtract(10, 5)}");
            Console.WriteLine($"  10 * 5 = {calc.Multiply(10, 5)}");
            Console.WriteLine($"  10 / 5 = {calc.Divide(10, 5)}");
            Console.WriteLine($"  Max(10, 5) = {calc.GetMax(10, 5)}");

            // Record example (C# 9+)
            var person = new Person("John", "Doe", 30);
            Console.WriteLine($"\nPerson Record:");
            Console.WriteLine($"  Name: {person.FirstName} {person.LastName}");
            Console.WriteLine($"  Age: {person.Age}");

            // With expression (C# 9+)
            var olderPerson = person with { Age = 31 };
            Console.WriteLine($"  After birthday: {olderPerson.FirstName} is now {olderPerson.Age}");

            // Pattern matching (C# 8+)
            Console.WriteLine("\nPattern Matching:");
            var value = 5;
            var result = value switch
            {
                < 0 => "Negative",
                0 => "Zero",
                > 0 and <= 10 => "Small positive",
                > 10 => "Large positive",
                _ => "Unknown"
            };
            Console.WriteLine($"  Value {value} is: {result}");

            // Nullable reference types (C# 8+)
            string? nullableString = null;
            Console.WriteLine($"\nNullable: {nullableString ?? "null value"}");

            // Range and index (C# 8+)
            var range = numbers[1..4]; // Skip first, take 3
            Console.WriteLine($"\nRange [1..4]: [{string.Join(", ", range)}]");

            // Command line arguments
            if (args.Length > 0)
            {
                Console.WriteLine($"\nArguments: {string.Join(", ", args)}");
            }

            Console.WriteLine("\n✓ Build completed successfully!");
        }
    }
}

