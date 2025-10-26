"""Utility functions for the example app."""
import os
import json
from typing import List, Dict, Any

def greet(name: str) -> str:
    """Return a greeting message."""
    return f"Hello, {name}!"

def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b

def process_data(items: List[int]) -> Dict[str, Any]:
    """Process a list of items and return statistics.
    
    This demonstrates common data processing patterns:
    - List comprehension
    - Dictionary creation
    - Built-in functions (sum, len, min, max)
    """
    return {
        "count": len(items),
        "sum": sum(items),
        "average": sum(items) / len(items) if items else 0,
        "min": min(items) if items else None,
        "max": max(items) if items else None,
        "doubled": [x * 2 for x in items]
    }

class FileHandler:
    """Handle file operations (common real-world use case)."""
    
    def __init__(self):
        self.encoding = "utf-8"
    
    def get_cwd(self) -> str:
        """Get current working directory."""
        return os.getcwd()
    
    def read_json(self, filepath: str) -> Dict:
        """Read JSON file."""
        with open(filepath, 'r', encoding=self.encoding) as f:
            return json.load(f)
    
    def write_json(self, filepath: str, data: Dict) -> None:
        """Write JSON file."""
        with open(filepath, 'w', encoding=self.encoding) as f:
            json.dump(data, f, indent=2)

