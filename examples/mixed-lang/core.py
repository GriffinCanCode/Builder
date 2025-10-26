"""Core data processing library."""

def process_data(data):
    """Process raw data."""
    return [x * 2 for x in data if x > 0]

def validate_data(data):
    """Validate data format."""
    return all(isinstance(x, (int, float)) for x in data)

def summarize_data(data):
    """Generate data summary."""
    return {
        'count': len(data),
        'sum': sum(data),
        'avg': sum(data) / len(data) if data else 0,
        'min': min(data) if data else None,
        'max': max(data) if data else None
    }

