module frontend.lsp.hover;

import std.algorithm;
import std.array;
import std.string;
import std.conv;
import frontend.lsp.protocol;
import frontend.lsp.workspace;
import infrastructure.config.workspace.ast : BuildFile, TargetDeclStmt, Field, Expr, ASTLocation = Location;
import languages.registry : getSupportedLanguageNames;

/// Hover information provider
struct HoverProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Provide hover information at a given position
    Hover* provideHover(string uri, Position pos)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return null;
        
        // Find what we're hovering over
        auto target = workspace.findTargetAtPosition(uri, pos);
        if (target !is null)
        {
            // Hovering over a target
            return buildTargetHover(*target, pos);
        }
        
        auto field = workspace.findFieldAtPosition(uri, pos);
        if (field !is null)
        {
            // Hovering over a field
            return buildFieldHover(*field, pos);
        }
        
        return null;
    }
    
    private Hover* buildTargetHover(ref const TargetDeclStmt target, Position pos)
    {
        auto hover = new Hover;
        
        // Build markdown documentation
        string md = "# Target: `" ~ target.name ~ "`\n\n";
        
        // Add type
        auto typeField = target.getField("type");
        if (typeField !is null)
        {
            md ~= "**Type:** " ~ getFieldValueString(typeField.value) ~ "\n\n";
        }
        
        // Add language
        auto langField = target.getField("language");
        if (langField !is null)
        {
            md ~= "**Language:** " ~ getFieldValueString(langField.value) ~ "\n\n";
        }
        
        // TODO: Implement array value inspection with the new AST structure
        // Add sources count
        auto sourcesField = target.getField("sources");
        if (sourcesField !is null)
        {
            md ~= "**Sources:** (see field)\n\n";
        }
        
        // Add dependencies count  
        auto depsField = target.getField("deps");
        if (depsField !is null)
        {
            md ~= "**Dependencies:** (see field)\n\n";
        }
        
        hover.contents = md;
        hover.range = Range(
            Position(cast(uint)(target.loc.line - 1), 0),
            Position(cast(uint)(target.loc.line - 1), 100)
        );
        
        return hover;
    }
    
    private Hover* buildFieldHover(ref const Field field, Position pos)
    {
        auto hover = new Hover;
        
        // Build markdown documentation
        string md = "## Field: `" ~ field.name ~ "`\n\n";
        
        // Add field-specific documentation
        md ~= getFieldDocumentation(field.name);
        
        // Add current value
        md ~= "\n\n**Current value:** " ~ formatFieldValue(field.value);
        
        hover.contents = md;
        hover.range = Range(
            Position(cast(uint)(field.loc.line - 1), 0),
            Position(cast(uint)(field.loc.line - 1), 100)
        );
        
        return hover;
    }
    
    private string getFieldDocumentation(string fieldName)
    {
        switch (fieldName)
        {
            case "type":
                return "**Target type** - Specifies what this target produces.\n" ~
                       "- `executable`: Produces an executable binary\n" ~
                       "- `library`: Produces a library\n" ~
                       "- `test`: Produces a test target\n" ~
                       "- `custom`: Custom build logic";
            
            case "language":
                // Dynamically generate list from registry
                auto supportedLangs = getSupportedLanguageNames().join(", ");
                return "**Programming language** - Specifies the source language (optional, inferred from sources if not provided).\n" ~
                       "Supported: " ~ supportedLangs;
            
            case "sources":
                return "**Source files** - List of source files to build.\n" ~
                       "Supports glob patterns like `src/**/*.py` for recursive matching.";
            
            case "deps":
                return "**Dependencies** - Other targets this target depends on.\n" ~
                       "Use `:name` for local targets or `//path:name` for targets in other directories.";
            
            case "flags":
                return "**Build flags** - Compiler or build flags to pass.\n" ~
                       "Example: `[\"-O2\", \"-Wall\"]`";
            
            case "env":
                return "**Environment variables** - Environment variables to set during build.\n" ~
                       "Example: `{\"PYTHONPATH\": \"/usr/lib/python\"}`";
            
            case "output":
                return "**Output file** - Name of the output file (optional).";
            
            case "includes":
                return "**Include directories** - Additional include/import paths.";
            
            case "config":
                return "**Configuration** - Additional target-specific configuration.";
            
            default:
                return "Target field";
        }
    }
    
    private string formatFieldValue(ref const Expr value)
    {
        // TODO: Implement proper Expr formatting with the new AST structure
        if (auto lit = cast(LiteralExpr)value)
        {
            return lit.value.toString();
        }
        else if (auto ident = cast(IdentExpr)value)
        {
            return "`" ~ ident.name ~ "`";
        }
        return "value";
    }
    
    private string getFieldValueString(ref const Expr value)
    {
        // TODO: Implement proper Expr value extraction with the new AST structure
        if (auto lit = cast(LiteralExpr)value)
        {
            return lit.value.toString();
        }
        else if (auto ident = cast(IdentExpr)value)
        {
            return ident.name;
        }
        return "";
    }
}

