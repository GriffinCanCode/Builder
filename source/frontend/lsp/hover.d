module frontend.lsp.hover;

import std.algorithm;
import std.array;
import std.string;
import std.conv;
import frontend.lsp.protocol;
import frontend.lsp.workspace;
import infrastructure.config.workspace.ast : BuildFile, TargetDeclStmt, Field, Expr, ASTLocation = Location,
    LiteralExpr, IdentExpr, BinaryExpr, UnaryExpr, CallExpr, MemberExpr, IndexExpr, TernaryExpr,
    Literal, LiteralKind;
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
            return buildTargetHover(target, pos);
        }
        
        auto field = workspace.findFieldAtPosition(uri, pos);
        if (field !is null)
        {
            // Hovering over a field
            return buildFieldHover(*field, pos);
        }
        
        return null;
    }
    
    private struct ArrayInfo
    {
        bool isArray;
        size_t count;
        string preview;
    }
    
    private ArrayInfo getArrayInfo(ref const Expr value)
    {
        ArrayInfo info;
        info.isArray = false;
        info.count = 0;
        info.preview = "";
        
        if (auto lit = cast(const(LiteralExpr))value)
        {
            if (lit.value.kind == LiteralKind.Array)
            {
                info.isArray = true;
                auto arr = lit.value.asArray();
                info.count = arr.length;
                
                // Generate preview of first few items
                if (arr.length > 0)
                {
                    string[] previews;
                    size_t maxPreview = arr.length < 3 ? arr.length : 3;
                    foreach (i; 0 .. maxPreview)
                    {
                        if (arr[i].kind == LiteralKind.String)
                            previews ~= arr[i].asString();
                        else
                            previews ~= arr[i].toString();
                    }
                    info.preview = previews.join(", ");
                    if (arr.length > 3)
                        info.preview ~= ", ...";
                }
            }
        }
        
        return info;
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
        
        // Add sources count
        auto sourcesField = target.getField("sources");
        if (sourcesField !is null)
        {
            auto arrayInfo = getArrayInfo(sourcesField.value);
            if (arrayInfo.isArray)
            {
                md ~= "**Sources:** " ~ arrayInfo.count.to!string ~ " file(s)";
                if (arrayInfo.preview.length > 0)
                    md ~= " - " ~ arrayInfo.preview;
                md ~= "\n\n";
            }
            else
            {
                md ~= "**Sources:** " ~ formatFieldValue(sourcesField.value) ~ "\n\n";
            }
        }
        
        // Add dependencies count  
        auto depsField = target.getField("deps");
        if (depsField !is null)
        {
            auto arrayInfo = getArrayInfo(depsField.value);
            if (arrayInfo.isArray)
            {
                md ~= "**Dependencies:** " ~ arrayInfo.count.to!string ~ " target(s)";
                if (arrayInfo.preview.length > 0)
                    md ~= " - " ~ arrayInfo.preview;
                md ~= "\n\n";
            }
            else
            {
                md ~= "**Dependencies:** " ~ formatFieldValue(depsField.value) ~ "\n\n";
            }
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
        if (auto lit = cast(const(LiteralExpr))value)
        {
            return lit.value.toString();
        }
        else if (auto ident = cast(const(IdentExpr))value)
        {
            return "`" ~ ident.name ~ "`";
        }
        else if (auto bin = cast(const(BinaryExpr))value)
        {
            return formatFieldValue(bin.left) ~ " " ~ bin.op ~ " " ~ formatFieldValue(bin.right);
        }
        else if (auto unary = cast(const(UnaryExpr))value)
        {
            return unary.op ~ formatFieldValue(unary.operand);
        }
        else if (auto call = cast(const(CallExpr))value)
        {
            string args = call.args.map!(a => formatFieldValue(a)).join(", ");
            return call.callee ~ "(" ~ args ~ ")";
        }
        else if (auto member = cast(const(MemberExpr))value)
        {
            return formatFieldValue(member.object) ~ "." ~ member.member;
        }
        else if (auto index = cast(const(IndexExpr))value)
        {
            return formatFieldValue(index.object) ~ "[" ~ formatFieldValue(index.index) ~ "]";
        }
        else if (auto ternary = cast(const(TernaryExpr))value)
        {
            return formatFieldValue(ternary.condition) ~ " ? " ~ 
                   formatFieldValue(ternary.trueExpr) ~ " : " ~ 
                   formatFieldValue(ternary.falseExpr);
        }
        return "<expression>";
    }
    
    private string getFieldValueString(ref const Expr value)
    {
        if (auto lit = cast(const(LiteralExpr))value)
        {
            // For simple string literals, return without quotes
            if (lit.value.kind == LiteralKind.String)
                return lit.value.asString();
            return lit.value.toString();
        }
        else if (auto ident = cast(const(IdentExpr))value)
        {
            return ident.name;
        }
        else if (auto bin = cast(const(BinaryExpr))value)
        {
            return getFieldValueString(bin.left) ~ " " ~ bin.op ~ " " ~ getFieldValueString(bin.right);
        }
        else if (auto call = cast(const(CallExpr))value)
        {
            return call.callee ~ "(...)";
        }
        else if (auto member = cast(const(MemberExpr))value)
        {
            return getFieldValueString(member.object) ~ "." ~ member.member;
        }
        return "";
    }
}

