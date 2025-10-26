"""Math utility functions."""

def multiply(a, b):
    """Multiply two numbers."""
    return a * b

def divide(a, b):
    """Divide two numbers."""
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b

def power(base, exp):
    """Raise base to the power of exp."""
    return base ** exp

