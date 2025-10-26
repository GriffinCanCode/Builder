#!/usr/bin/env python3
"""Fast batch Python syntax validator using AST parsing.

Validates multiple Python files in a single process using AST parsing,
avoiding expensive per-file process spawning.
"""

import ast
import sys
import json
from pathlib import Path
from typing import Dict, List, Optional


def validate_file(filepath: str) -> Dict[str, any]:
    """Validate a single Python file's syntax.
    
    Args:
        filepath: Path to Python file
        
    Returns:
        Dict with validation result and metadata
    """
    result = {
        "file": filepath,
        "valid": False,
        "error": None,
        "has_main": False,
        "has_main_guard": False,
        "is_executable": False
    }
    
    try:
        path = Path(filepath)
        if not path.exists():
            result["error"] = f"File not found: {filepath}"
            return result
            
        source = path.read_text(encoding="utf-8")
        
        # Parse AST - will raise SyntaxError if invalid
        tree = ast.parse(source, filename=filepath)
        result["valid"] = True
        
        # Analyze entry points
        for node in ast.walk(tree):
            # Check for main() function
            if isinstance(node, ast.FunctionDef) and node.name == "main":
                result["has_main"] = True
                
            # Check for if __name__ == "__main__" guard
            if isinstance(node, ast.If):
                if _is_main_guard(node):
                    result["has_main_guard"] = True
                    result["is_executable"] = True
                    
    except SyntaxError as e:
        result["error"] = f"{e.msg} at line {e.lineno}"
    except Exception as e:
        result["error"] = str(e)
        
    return result


def _is_main_guard(node: ast.If) -> bool:
    """Check if node is if __name__ == "__main__" pattern."""
    if not isinstance(node.test, ast.Compare):
        return False
        
    comp = node.test
    
    # Check for __name__ on left side
    if not (isinstance(comp.left, ast.Name) and comp.left.id == "__name__"):
        return False
        
    # Check for == operator
    if not any(isinstance(op, ast.Eq) for op in comp.ops):
        return False
        
    # Check for "__main__" on right side
    for comparator in comp.comparators:
        if isinstance(comparator, ast.Constant) and comparator.value == "__main__":
            return True
            
    return False


def validate_batch(filepaths: List[str]) -> Dict[str, any]:
    """Validate multiple Python files in batch.
    
    Args:
        filepaths: List of Python file paths
        
    Returns:
        Dict with overall results and per-file details
    """
    results = []
    valid_count = 0
    
    for filepath in filepaths:
        file_result = validate_file(filepath)
        results.append(file_result)
        if file_result["valid"]:
            valid_count += 1
            
    return {
        "success": valid_count == len(filepaths),
        "total": len(filepaths),
        "valid": valid_count,
        "invalid": len(filepaths) - valid_count,
        "files": results
    }


def main():
    """CLI entry point for batch validation."""
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "No files provided"}))
        sys.exit(1)
        
    filepaths = sys.argv[1:]
    result = validate_batch(filepaths)
    
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()

