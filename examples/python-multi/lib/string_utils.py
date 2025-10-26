"""String utility functions."""

def reverse(text):
    """Reverse a string."""
    return text[::-1]

def capitalize_words(text):
    """Capitalize each word in a string."""
    return ' '.join(word.capitalize() for word in text.split())

def truncate(text, length):
    """Truncate text to specified length."""
    return text[:length] + "..." if len(text) > length else text

