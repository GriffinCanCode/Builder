"""Data processor application."""

def main():
    """Run data processing pipeline."""
    print("=== Builder Mixed-Language Example ===\n")
    
    raw_data = [1, -2, 3, 4, -5, 6, 7, 8]
    
    print("Data Processing Pipeline:")
    print(f"  Raw data: {raw_data}")
    print(f"  Valid: {validate_data(raw_data)}")
    
    processed = process_data(raw_data)
    print(f"  Processed: {processed}")
    
    summary = summarize_data(processed)
    print("\nData Summary:")
    for key, value in summary.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    from core import process_data, validate_data, summarize_data
    main()

