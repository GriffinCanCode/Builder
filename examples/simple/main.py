"""Main application entry point."""

def main():
    """Run the main application."""
    from utils import greet, add
    
    print(greet("Builder"))
    print(f"2 + 3 = {add(2, 3)}")

if __name__ == "__main__":
    main()

