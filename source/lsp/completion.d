module lsp.completion;

import std.algorithm;
import std.array;
import std.string;
import lsp.protocol;
import lsp.workspace;
import config.workspace.ast;
import config.parsing.lexer;

/// Completion provider for Builderfile
struct CompletionProvider
{
    private WorkspaceManager workspace;
    
    this(WorkspaceManager workspace)
    {
        this.workspace = workspace;
    }
    
    /// Provide completion items at a given position
    CompletionItem[] provideCompletion(string uri, Position pos)
    {
        auto doc = workspace.getDocument(uri);
        if (doc is null)
            return [];
        
        // Determine context
        auto context = getCompletionContext(doc.text, pos);
        
        final switch (context.type)
        {
            case ContextType.Field:
                return provideFieldCompletion();
            case ContextType.TypeValue:
                return provideTypeValueCompletion();
            case ContextType.LanguageValue:
                return provideLanguageCompletion();
            case ContextType.DependencyValue:
                return provideDependencyCompletion();
            case ContextType.ArrayItem:
                return provideArrayItemCompletion(context);
            case ContextType.Unknown:
                return provideGeneralCompletion();
        }
    }
    
    private CompletionItem[] provideFieldCompletion()
    {
        // Suggest field names
        return [
            createField("type", "Target type (executable, library, test, custom)"),
            createField("language", "Programming language (optional, inferred from sources)"),
            createField("sources", "Source files (glob patterns supported)"),
            createField("deps", "Dependencies on other targets"),
            createField("flags", "Compiler/build flags"),
            createField("env", "Environment variables"),
            createField("output", "Output file name"),
            createField("includes", "Include directories"),
            createField("config", "Additional configuration")
        ];
    }
    
    private CompletionItem[] provideTypeValueCompletion()
    {
        return [
            createEnum("executable", "Produces an executable binary"),
            createEnum("library", "Produces a library"),
            createEnum("test", "Produces a test target"),
            createEnum("custom", "Custom build logic")
        ];
    }
    
    private CompletionItem[] provideLanguageCompletion()
    {
        return [
            createEnum("python", "Python language"),
            createEnum("javascript", "JavaScript language"),
            createEnum("typescript", "TypeScript language"),
            createEnum("go", "Go language"),
            createEnum("rust", "Rust language"),
            createEnum("d", "D language"),
            createEnum("c", "C language"),
            createEnum("cpp", "C++ language"),
            createEnum("java", "Java language"),
            createEnum("csharp", "C# language"),
            createEnum("ruby", "Ruby language"),
            createEnum("php", "PHP language"),
            createEnum("lua", "Lua language"),
            createEnum("perl", "Perl language"),
            createEnum("r", "R language"),
            createEnum("nim", "Nim language"),
            createEnum("ocaml", "OCaml language"),
            createEnum("haskell", "Haskell language"),
            createEnum("elm", "Elm language"),
            createEnum("zig", "Zig language")
        ];
    }
    
    private CompletionItem[] provideDependencyCompletion()
    {
        // Get all available targets
        auto targets = workspace.getAllTargetNames();
        
        CompletionItem[] items;
        foreach (target; targets)
        {
            CompletionItem item;
            item.label = target;
            item.kind = CompletionItemKind.Reference;
            item.detail = "Target dependency";
            item.documentation = "Depends on target: " ~ target;
            item.insertText = "\"" ~ target ~ "\"";
            items ~= item;
        }
        
        return items;
    }
    
    private CompletionItem[] provideArrayItemCompletion(CompletionContext context)
    {
        // Determine what kind of array based on field name
        if (context.fieldName == "deps")
            return provideDependencyCompletion();
        
        return [];
    }
    
    private CompletionItem[] provideGeneralCompletion()
    {
        // Default: suggest 'target' keyword
        CompletionItem item;
        item.label = "target";
        item.kind = CompletionItemKind.Keyword;
        item.detail = "Define a build target";
        item.documentation = "Create a new target definition";
        item.insertText = "target(\"${1:name}\") {\n    type: ${2:executable};\n    sources: [\"${3:main.py}\"];\n}";
        return [item];
    }
    
    private CompletionItem createField(string name, string doc)
    {
        CompletionItem item;
        item.label = name;
        item.kind = CompletionItemKind.Field;
        item.detail = "Field";
        item.documentation = doc;
        item.insertText = name ~ ": ";
        return item;
    }
    
    private CompletionItem createEnum(string name, string doc)
    {
        CompletionItem item;
        item.label = name;
        item.kind = CompletionItemKind.EnumMember;
        item.detail = "Value";
        item.documentation = doc;
        item.insertText = name;
        return item;
    }
    
    private CompletionContext getCompletionContext(string text, Position pos)
    {
        // Get current line
        auto lines = text.split("\n");
        if (pos.line >= lines.length)
            return CompletionContext(ContextType.Unknown);
        
        string currentLine = lines[pos.line];
        string beforeCursor = currentLine[0 .. min(pos.character, currentLine.length)];
        
        // Check if we're in a field value position (after colon)
        if (beforeCursor.canFind(":"))
        {
            // Extract field name
            auto fieldStart = beforeCursor.lastIndexOf("{");
            if (fieldStart == -1)
                fieldStart = 0;
            
            auto fieldLine = beforeCursor[fieldStart .. $];
            auto colonPos = fieldLine.lastIndexOf(":");
            if (colonPos > 0)
            {
                auto fieldName = fieldLine[0 .. colonPos].strip;
                
                // Check field type
                if (fieldName == "type")
                    return CompletionContext(ContextType.TypeValue);
                if (fieldName == "language")
                    return CompletionContext(ContextType.LanguageValue);
                if (fieldName == "deps")
                    return CompletionContext(ContextType.DependencyValue, fieldName);
            }
        }
        
        // Check if we're in an array
        if (beforeCursor.canFind("[") && !beforeCursor[beforeCursor.lastIndexOf("[") .. $].canFind("]"))
        {
            // We're inside an array
            // Try to find the field name
            auto fieldStart = currentLine.lastIndexOf("{");
            if (fieldStart == -1)
                fieldStart = 0;
            
            auto fieldLine = currentLine[fieldStart .. $];
            auto colonPos = fieldLine.indexOf(":");
            if (colonPos > 0)
            {
                auto fieldName = fieldLine[0 .. colonPos].strip;
                return CompletionContext(ContextType.ArrayItem, fieldName);
            }
            
            return CompletionContext(ContextType.ArrayItem);
        }
        
        // Check if we're after a closing brace (field position)
        auto trimmed = beforeCursor.stripRight;
        if (trimmed.endsWith("{") || trimmed.endsWith(";"))
            return CompletionContext(ContextType.Field);
        
        // Default: unknown context
        return CompletionContext(ContextType.Unknown);
    }
}

private enum ContextType
{
    Unknown,
    Field,
    TypeValue,
    LanguageValue,
    DependencyValue,
    ArrayItem
}

private struct CompletionContext
{
    ContextType type;
    string fieldName;
    
    this(ContextType type, string fieldName = "")
    {
        this.type = type;
        this.fieldName = fieldName;
    }
}

