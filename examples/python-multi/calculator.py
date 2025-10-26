"""Calculator application using utility libraries."""

def main():
    """Run the calculator."""
    print("=== Builder Calculator ===\n")
    
    # Test math utils
    print("Math Operations:")
    print(f"  5 × 3 = {multiply(5, 3)}")
    print(f"  10 ÷ 2 = {divide(10, 2)}")
    print(f"  2³ = {power(2, 3)}")
    
    # Test string utils
    print("\nString Operations:")
    text = "hello builder"
    print(f"  Original: {text}")
    print(f"  Reversed: {reverse(text)}")
    print(f"  Capitalized: {capitalize_words(text)}")
    print(f"  Truncated (5): {truncate(text, 5)}")

if __name__ == "__main__":
    from lib.math_utils import multiply, divide, power
    from lib.string_utils import reverse, capitalize_words, truncate
    main()

