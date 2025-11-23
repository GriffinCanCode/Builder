# Language Configuration Files

JSON configuration files for tree-sitter language parsers.

## Format

Each configuration file maps tree-sitter node types to Builder's AST symbol types.

### Structure

```json
{
  "language": {
    "id": "language_identifier",
    "display": "Display Name",
    "extensions": [".ext1", ".ext2"],
    "grammar": "tree-sitter-grammar-name"
  },
  "node_types": {
    "tree_sitter_node_type": "SymbolType"
  },
  "imports": {
    "node_types": ["import_node_types"],
    "patterns": {
      "node_type": "field_name"
    }
  },
  "skip_nodes": ["node_types_to_skip"],
  "visibility": {
    "default": "public|private",
    "modifiers": {
      "public": ["public_keywords"],
      "private": ["private_keywords"]
    },
    "patterns": {
      "public": "regex_pattern",
      "private": "regex_pattern"
    }
  },
  "dependencies": {
    "type_nodes": ["type_usage_nodes"],
    "member_nodes": ["member_access_nodes"]
  }
}
```

### Symbol Types

Available symbol types (from `engine.caching.incremental.ast_dependency`):
- `Class` - Class/interface/trait definitions
- `Struct` - Struct definitions
- `Function` - Standalone functions
- `Method` - Class/struct methods
- `Field` - Class/struct fields
- `Enum` - Enum definitions
- `Typedef` - Type aliases
- `Namespace` - Namespace/package/module definitions
- `Template` - Template/generic definitions
- `Variable` - Global/module variables

## Available Configurations

- **python.json** - Python 3.x
- **java.json** - Java 8+
- **typescript.json** - TypeScript/TSX

## Adding a New Language

1. Find the tree-sitter grammar node types:
   ```bash
   # View grammar
   tree-sitter parse example.lang --debug
   ```

2. Create config file `language.json`

3. Map node types to symbol types

4. Define import patterns

5. Configure visibility rules

6. Test with sample code

## See Also

- [Tree-sitter Integration](../treesitter/README.md)
- [Language Grammar Repos](https://github.com/tree-sitter)

