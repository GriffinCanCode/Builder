module config.interpretation.dsl;

import std.conv;
import std.algorithm;
import std.array;
import std.string;
import std.json;
import config.parsing.lexer;
import config.workspace.ast;
import config.schema.schema;
import errors;

/// Recursive descent parser for Builderfile DSL
/// Uses parser combinator patterns for elegant composition
struct DSLParser
{
    private Token[] tokens;
    private size_t current;
    private string filePath;
    
    this(Token[] tokens, string filePath = "")
    {
        this.tokens = tokens;
        this.filePath = filePath;
    }
    
    /// Parse Builderfile file into AST
    Result!(BuildFile, BuildError) parse()
    {
        BuildFile file;
        file.filePath = filePath;
        
        while (!isAtEnd())
        {
            auto targetResult = parseTarget();
            if (targetResult.isErr)
                return Err!(BuildFile, BuildError)(targetResult.unwrapErr());
            
            file.targets ~= targetResult.unwrap();
        }
        
        if (file.targets.empty)
        {
            auto error = new ParseError(filePath, 
                "Builderfile must contain at least one target",
                ErrorCode.InvalidBuildFile);
            return Err!(BuildFile, BuildError)(error);
        }
        
        return Ok!(BuildFile, BuildError)(file);
    }
    
    /// Parse single target declaration
    private Result!(TargetDecl, BuildError) parseTarget()
    {
        auto token = peek();
        
        // Expect: target
        if (!match(TokenType.Target))
        {
            return error!(TargetDecl)("Expected 'target' keyword");
        }
        
        size_t line = previous().line;
        size_t col = previous().column;
        
        // Expect: (
        if (!match(TokenType.LeftParen))
        {
            return error!(TargetDecl)("Expected '(' after 'target'");
        }
        
        // Expect: "name"
        if (!check(TokenType.String))
        {
            return error!(TargetDecl)("Expected target name as string literal");
        }
        
        string name = advance().value;
        
        // Expect: )
        if (!match(TokenType.RightParen))
        {
            return error!(TargetDecl)("Expected ')' after target name");
        }
        
        // Expect: {
        if (!match(TokenType.LeftBrace))
        {
            return error!(TargetDecl)("Expected '{' to begin target body");
        }
        
        // Parse fields
        Field[] fields;
        
        while (!check(TokenType.RightBrace) && !isAtEnd())
        {
            auto fieldResult = parseField();
            if (fieldResult.isErr)
                return Err!(TargetDecl, BuildError)(fieldResult.unwrapErr());
            
            fields ~= fieldResult.unwrap();
        }
        
        // Expect: }
        if (!match(TokenType.RightBrace))
        {
            return error!(TargetDecl)("Expected '}' to end target body");
        }
        
        return Ok!(TargetDecl, BuildError)(TargetDecl(name, fields, line, col));
    }
    
    /// Parse field assignment
    private Result!(Field, BuildError) parseField()
    {
        auto token = peek();
        size_t line = token.line;
        size_t col = token.column;
        
        // Get field name (keyword or identifier)
        string fieldName;
        
        switch (token.type)
        {
            case TokenType.Type:
                fieldName = "type";
                advance();
                break;
            case TokenType.Language:
                fieldName = "language";
                advance();
                break;
            case TokenType.Sources:
                fieldName = "sources";
                advance();
                break;
            case TokenType.Deps:
                fieldName = "deps";
                advance();
                break;
            case TokenType.Flags:
                fieldName = "flags";
                advance();
                break;
            case TokenType.Env:
                fieldName = "env";
                advance();
                break;
            case TokenType.Output:
                fieldName = "output";
                advance();
                break;
            case TokenType.Includes:
                fieldName = "includes";
                advance();
                break;
            case TokenType.Config:
                fieldName = "config";
                advance();
                break;
            case TokenType.Identifier:
                fieldName = advance().value;
                break;
            default:
                return error!(Field)("Expected field name");
        }
        
        // Expect: :
        if (!match(TokenType.Colon))
        {
            return error!(Field)("Expected ':' after field name");
        }
        
        // Parse value
        auto valueResult = parseExpression();
        if (valueResult.isErr)
            return Err!(Field, BuildError)(valueResult.unwrapErr());
        
        auto value = valueResult.unwrap();
        
        // Expect: ;
        if (!match(TokenType.Semicolon))
        {
            return error!(Field)("Expected ';' after field value");
        }
        
        return Ok!(Field, BuildError)(Field(fieldName, value, line, col));
    }
    
    /// Parse expression (literals, arrays, maps)
    private Result!(ExpressionValue, BuildError) parseExpression()
    {
        auto token = peek();
        
        switch (token.type)
        {
            case TokenType.String:
                advance();
                return Ok!(ExpressionValue, BuildError)(
                    ExpressionValue.fromString(token.value, token.line, token.column)
                );
            
            case TokenType.Number:
                advance();
                long num = token.value.to!long;
                return Ok!(ExpressionValue, BuildError)(
                    ExpressionValue.fromNumber(num, token.line, token.column)
                );
            
            case TokenType.Identifier:
            case TokenType.Executable:
            case TokenType.Library:
            case TokenType.Test:
            case TokenType.Custom:
                advance();
                return Ok!(ExpressionValue, BuildError)(
                    ExpressionValue.fromIdentifier(token.value, token.line, token.column)
                );
            
            case TokenType.LeftBracket:
                return parseArray();
            
            case TokenType.LeftBrace:
                return parseMap();
            
            default:
                return error!(ExpressionValue)("Expected expression value");
        }
    }
    
    /// Parse array literal
    private Result!(ExpressionValue, BuildError) parseArray()
    {
        size_t line = peek().line;
        size_t col = peek().column;
        
        advance(); // [
        
        ExpressionValue[] elements;
        
        while (!check(TokenType.RightBracket) && !isAtEnd())
        {
            auto elemResult = parseExpression();
            if (elemResult.isErr)
                return Err!(ExpressionValue, BuildError)(elemResult.unwrapErr());
            
            elements ~= elemResult.unwrap();
            
            if (!check(TokenType.RightBracket))
            {
                if (!match(TokenType.Comma))
                {
                    return error!(ExpressionValue)("Expected ',' or ']' in array");
                }
            }
        }
        
        if (!match(TokenType.RightBracket))
        {
            return error!(ExpressionValue)("Expected ']' to close array");
        }
        
        return Ok!(ExpressionValue, BuildError)(
            ExpressionValue.fromArray(elements, line, col)
        );
    }
    
    /// Parse map literal
    private Result!(ExpressionValue, BuildError) parseMap()
    {
        size_t line = peek().line;
        size_t col = peek().column;
        
        advance(); // {
        
        ExpressionValue[string] pairs;
        
        while (!check(TokenType.RightBrace) && !isAtEnd())
        {
            // Parse key (must be string)
            if (!check(TokenType.String))
            {
                return error!(ExpressionValue)("Expected string key in map");
            }
            
            string key = advance().value;
            
            // Expect: :
            if (!match(TokenType.Colon))
            {
                return error!(ExpressionValue)("Expected ':' after map key");
            }
            
            // Parse value (can be any expression type)
            auto valueResult = parseExpression();
            if (valueResult.isErr)
                return Err!(ExpressionValue, BuildError)(valueResult.unwrapErr());
            
            pairs[key] = valueResult.unwrap();
            
            if (!check(TokenType.RightBrace))
            {
                if (!match(TokenType.Comma))
                {
                    return error!(ExpressionValue)("Expected ',' or '}' in map");
                }
            }
        }
        
        if (!match(TokenType.RightBrace))
        {
            return error!(ExpressionValue)("Expected '}' to close map");
        }
        
        return Ok!(ExpressionValue, BuildError)(
            ExpressionValue.fromMap(pairs, line, col)
        );
    }
    
    /// Parsing utilities
    
    private bool match(TokenType type)
    {
        if (check(type))
        {
            advance();
            return true;
        }
        return false;
    }
    
    private bool check(TokenType type) const
    {
        if (isAtEnd())
            return false;
        return peek().type == type;
    }
    
    private Token advance()
    {
        if (!isAtEnd())
            current++;
        return previous();
    }
    
    private bool isAtEnd() const
    {
        return peek().type == TokenType.EOF;
    }
    
    private Token peek() const
    {
        return tokens[current];
    }
    
    private Token previous() const
    {
        return tokens[current - 1];
    }
    
    private Result!(T, BuildError) error(T)(string message)
    {
        auto token = peek();
        auto err = new ParseError(filePath, message, ErrorCode.ParseFailed);
        err.line = token.line;
        err.column = token.column;
        return Err!(T, BuildError)(err);
    }
}

/// Semantic analyzer - converts AST to Target objects with validation
struct SemanticAnalyzer
{
    private string workspaceRoot;
    private string buildFilePath;
    
    this(string workspaceRoot, string buildFilePath)
    {
        this.workspaceRoot = workspaceRoot;
        this.buildFilePath = buildFilePath;
    }
    
    /// Analyze and convert AST to targets
    Result!(Target[], BuildError) analyze(ref BuildFile ast)
    {
        Target[] targets;
        
        foreach (ref targetDecl; ast.targets)
        {
            auto targetResult = analyzeTarget(targetDecl);
            if (targetResult.isErr)
                return Err!(Target[], BuildError)(targetResult.unwrapErr());
            
            targets ~= targetResult.unwrap();
        }
        
        return Ok!(Target[], BuildError)(targets);
    }
    
    /// Analyze single target
    private Result!(Target, BuildError) analyzeTarget(ref TargetDecl decl)
    {
        Target target;
        target.name = decl.name;
        target.language = TargetLanguage.Generic; // Default to Generic for inference
        
        // Parse type field (required)
        if (!decl.hasField("type"))
        {
            return error!(Target)(decl, "Missing required field 'type'");
        }
        
        auto typeField = decl.getField("type");
        target.type = parseTargetType(typeField.value);
        
        // Parse language field (optional, can be inferred)
        if (decl.hasField("language"))
        {
            auto langField = decl.getField("language");
            target.language = parseLanguage(langField.value);
        }
        
        // Parse sources field (required)
        if (!decl.hasField("sources"))
        {
            return error!(Target)(decl, "Missing required field 'sources'");
        }
        
        auto sourcesField = decl.getField("sources");
        try
        {
            target.sources = sourcesField.value.asStringArray();
        }
        catch (Exception e)
        {
            return error!(Target)(decl, "Field 'sources' must be an array of strings");
        }
        
        // Infer language if not specified
        if (target.language == TargetLanguage.Generic && !target.sources.empty)
        {
            target.language = inferLanguageFromSources(target.sources);
        }
        
        // Parse optional fields
        
        if (decl.hasField("deps"))
        {
            auto depsField = decl.getField("deps");
            try
            {
                target.deps = depsField.value.asStringArray();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'deps' must be an array of strings");
            }
        }
        
        if (decl.hasField("flags"))
        {
            auto flagsField = decl.getField("flags");
            try
            {
                target.flags = flagsField.value.asStringArray();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'flags' must be an array of strings");
            }
        }
        
        if (decl.hasField("env"))
        {
            auto envField = decl.getField("env");
            try
            {
                target.env = envField.value.asMap();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'env' must be a map of strings");
            }
        }
        
        if (decl.hasField("output"))
        {
            auto outputField = decl.getField("output");
            try
            {
                target.outputPath = outputField.value.asString();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'output' must be a string");
            }
        }
        
        if (decl.hasField("includes"))
        {
            auto includesField = decl.getField("includes");
            try
            {
                target.includes = includesField.value.asStringArray();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'includes' must be an array of strings");
            }
        }
        
        // Parse language-specific configuration
        if (decl.hasField("config"))
        {
            auto configField = decl.getField("config");
            try
            {
                import std.json : parseJSON, toJSON;
                // Convert map to JSON string for storage
                auto configMap = configField.value.asMap();
                JSONValue jsonConfig = parseJSON("{}");
                foreach (key, value; configMap)
                {
                    jsonConfig[key] = value;
                }
                // Store config keyed by language name for flexibility
                string configKey = target.language == TargetLanguage.Generic ? 
                                   "config" : target.language.to!string.toLower;
                target.langConfig[configKey] = jsonConfig.toJSON();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Field 'config' must be a map");
            }
        }
        
        return Ok!(Target, BuildError)(target);
    }
    
    /// Parse target type from expression
    private TargetType parseTargetType(const ref ExpressionValue value) const
    {
        if (value.kind != ExpressionValue.Kind.Identifier)
            return TargetType.Custom;
        
        string typeName = value.identifierValue.name.toLower;
        
        switch (typeName)
        {
            case "executable": return TargetType.Executable;
            case "library": return TargetType.Library;
            case "test": return TargetType.Test;
            default: return TargetType.Custom;
        }
    }
    
    /// Parse language from expression
    private TargetLanguage parseLanguage(const ref ExpressionValue value) const
    {
        if (value.kind != ExpressionValue.Kind.Identifier)
            return TargetLanguage.Generic;
        
        string langName = value.identifierValue.name.toLower;
        
        switch (langName)
        {
            case "d": return TargetLanguage.D;
            case "python": case "py": return TargetLanguage.Python;
            case "javascript": case "js": return TargetLanguage.JavaScript;
            case "typescript": case "ts": return TargetLanguage.TypeScript;
            case "go": return TargetLanguage.Go;
            case "rust": case "rs": return TargetLanguage.Rust;
            case "cpp": case "c++": return TargetLanguage.Cpp;
            case "c": return TargetLanguage.C;
            case "java": return TargetLanguage.Java;
            case "kotlin": case "kt": return TargetLanguage.Kotlin;
            case "csharp": case "cs": case "c#": return TargetLanguage.CSharp;
            case "zig": return TargetLanguage.Zig;
            case "swift": return TargetLanguage.Swift;
            case "ruby": case "rb": return TargetLanguage.Ruby;
            case "php": return TargetLanguage.PHP;
            case "scala": return TargetLanguage.Scala;
            case "elixir": case "ex": return TargetLanguage.Elixir;
            case "nim": return TargetLanguage.Nim;
            case "lua": return TargetLanguage.Lua;
            case "r": return TargetLanguage.R;
            default: return TargetLanguage.Generic;
        }
    }
    
    /// Infer language from source file extensions
    private TargetLanguage inferLanguageFromSources(string[] sources)
    {
        import std.path : extension;
        
        if (sources.empty)
            return TargetLanguage.Generic;
        
        string ext = extension(sources[0]);
        
        switch (ext)
        {
            case ".d": return TargetLanguage.D;
            case ".py": return TargetLanguage.Python;
            case ".js": return TargetLanguage.JavaScript;
            case ".ts": return TargetLanguage.TypeScript;
            case ".go": return TargetLanguage.Go;
            case ".rs": return TargetLanguage.Rust;
            case ".cpp": case ".cc": case ".cxx": return TargetLanguage.Cpp;
            case ".c": return TargetLanguage.C;
            case ".java": return TargetLanguage.Java;
            case ".R": case ".r": return TargetLanguage.R;
            default: return TargetLanguage.Generic;
        }
    }
    
    private Result!(T, BuildError) error(T)(ref TargetDecl decl, string message)
    {
        auto err = new ParseError(buildFilePath, message, ErrorCode.InvalidBuildFile);
        err.line = decl.line;
        err.column = decl.column;
        return Err!(T, BuildError)(err);
    }
}

/// High-level API for parsing DSL Builderfile files
Result!(Target[], BuildError) parseDSL(string source, string filePath, string workspaceRoot)
{
    // Lex
    auto lexResult = lex(source, filePath);
    if (lexResult.isErr)
        return Err!(Target[], BuildError)(lexResult.unwrapErr());
    
    auto tokens = lexResult.unwrap();
    
    // Parse
    auto parser = DSLParser(tokens, filePath);
    auto parseResult = parser.parse();
    if (parseResult.isErr)
        return Err!(Target[], BuildError)(parseResult.unwrapErr());
    
    auto ast = parseResult.unwrap();
    
    // Semantic analysis
    auto analyzer = SemanticAnalyzer(workspaceRoot, filePath);
    return analyzer.analyze(ast);
}

unittest
{
    import std.stdio;
    
    // Test basic DSL parsing
    string dsl = `
        target("app") {
            type: executable;
            language: python;
            sources: ["main.py"];
        }
    `;
    
    auto result = parseDSL(dsl, "Builderfile", "/tmp");
    assert(result.isOk);
    
    auto targets = result.unwrap();
    assert(targets.length == 1);
    assert(targets[0].name == "app");
    assert(targets[0].type == TargetType.Executable);
    assert(targets[0].language == TargetLanguage.Python);
}

