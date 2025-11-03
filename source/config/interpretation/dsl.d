module config.interpretation.dsl;

import std.conv;
import std.algorithm;
import std.array;
import std.string;
import std.json;
import config.parsing.lexer;
import config.parsing.exprparser;
import config.workspace.ast;
import config.schema.schema;
import errors;
import languages.registry;

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
            auto token = peek();
            
            // Check if this is a repository or target declaration
            if (token.type == TokenType.Repository)
            {
                auto repoResult = parseRepository();
                if (repoResult.isErr)
                    return Err!(BuildFile, BuildError)(repoResult.unwrapErr());
                
                file.repositories ~= repoResult.unwrap();
            }
            else
            {
                auto targetResult = parseTarget();
                if (targetResult.isErr)
                    return Err!(BuildFile, BuildError)(targetResult.unwrapErr());
                
                file.targets ~= targetResult.unwrap();
            }
        }
        
        if (file.targets.empty && file.repositories.empty)
        {
            auto error = new ParseError(filePath, 
                "Builderfile is empty or contains no valid declarations",
                ErrorCode.InvalidBuildFile);
            error.addSuggestion("Add at least one target or repository definition to the Builderfile");
            error.addSuggestion("See examples/ directory for valid Builderfile examples");
            error.addSuggestion("Run 'builder init' to create a template Builderfile");
            error.addSuggestion("Check docs/architecture/DSL.md for syntax");
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
        
        // Validate target name is not empty or whitespace-only
        import std.string : strip;
        if (name.strip().empty)
        {
            return error!(TargetDecl)("Target name cannot be empty or whitespace-only");
        }
        
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
    
    /// Parse single repository declaration
    private Result!(RepositoryDecl, BuildError) parseRepository()
    {
        auto token = peek();
        
        // Expect: repository
        if (!match(TokenType.Repository))
        {
            return error!(RepositoryDecl)("Expected 'repository' keyword");
        }
        
        size_t line = previous().line;
        size_t col = previous().column;
        
        // Expect: (
        if (!match(TokenType.LeftParen))
        {
            return error!(RepositoryDecl)("Expected '(' after 'repository'");
        }
        
        // Expect: "name"
        if (!check(TokenType.String))
        {
            return error!(RepositoryDecl)("Expected repository name as string literal");
        }
        
        string name = advance().value;
        
        // Validate repository name is not empty or whitespace-only
        import std.string : strip;
        if (name.strip().empty)
        {
            return error!(RepositoryDecl)("Repository name cannot be empty or whitespace-only");
        }
        
        // Expect: )
        if (!match(TokenType.RightParen))
        {
            return error!(RepositoryDecl)("Expected ')' after repository name");
        }
        
        // Expect: {
        if (!match(TokenType.LeftBrace))
        {
            return error!(RepositoryDecl)("Expected '{' to begin repository body");
        }
        
        // Parse fields
        Field[] fields;
        
        while (!check(TokenType.RightBrace) && !isAtEnd())
        {
            auto fieldResult = parseField();
            if (fieldResult.isErr)
                return Err!(RepositoryDecl, BuildError)(fieldResult.unwrapErr());
            
            fields ~= fieldResult.unwrap();
        }
        
        // Expect: }
        if (!match(TokenType.RightBrace))
        {
            return error!(RepositoryDecl)("Expected '}' to end repository body");
        }
        
        return Ok!(RepositoryDecl, BuildError)(RepositoryDecl(name, fields, line, col));
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
    
    /// Parse expression - delegates to unified ExprParser (single source of truth)
    private Result!(ExpressionValue, BuildError) parseExpression()
    {
        // Create expression parser starting from current position
        auto exprParser = new ExprParser(tokens[current .. $], filePath);
        
        // Parse and convert to ExpressionValue
        auto result = exprParser.parseAsExpressionValue();
        
        if (result.isOk)
        {
            // Advance current position by how many tokens were consumed
            current += exprParser.position();
        }
        
        return result;
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
            string message = "Target '" ~ decl.name ~ "' missing required field 'type'\n\n" ~
                "All targets must specify a type. Available types:\n" ~
                "  - executable: Builds a binary executable\n" ~
                "  - library: Builds a library (static or shared)\n" ~
                "  - test: Runs tests\n" ~
                "  - custom: Custom build command\n\n" ~
                "Example:\n" ~
                "  target(\"" ~ decl.name ~ "\") {\n" ~
                "    type: executable;\n" ~
                "    sources: [\"*.d\"];\n" ~
                "  }";
            return error!(Target)(decl, message);
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
            string typeStr = target.type == TargetType.Custom ? "custom" : 
                            target.type == TargetType.Executable ? "executable" :
                            target.type == TargetType.Library ? "library" : "test";
            
            string message = "Target '" ~ decl.name ~ "' missing required field 'sources'\n\n" ~
                "All targets must have a 'sources' field, even custom targets.\n";
            
            if (target.type == TargetType.Custom)
            {
                message ~= "\nFor custom targets, sources can be:\n" ~
                    "  - Build script files (e.g., Makefile)\n" ~
                    "  - Marker files to track changes\n" ~
                    "  - Input files that trigger rebuild\n";
            }
            
            message ~= "\nExample:\n" ~
                "  target(\"" ~ decl.name ~ "\") {\n" ~
                "    type: " ~ typeStr ~ ";\n" ~
                "    sources: ";
            
            if (target.type == TargetType.Custom)
                message ~= "[\"Makefile\"]";
            else
                message ~= "[\"src/**/*.d\"]";
            
            message ~= ";\n";
            
            if (target.type == TargetType.Custom)
            {
                message ~= "    deps: [\"//other:target\"];\n";
            }
            
            message ~= "  }";
            
            return error!(Target)(decl, message);
        }
        
        auto sourcesField = decl.getField("sources");
        auto sourcesResult = sourcesField.value.asStringArray();
        if (sourcesResult.isErr)
        {
            return error!(Target)(decl, "Field 'sources' must be an array of strings");
        }
        target.sources = sourcesResult.unwrap();
        
        // Infer language if not specified
        if (target.language == TargetLanguage.Generic && !target.sources.empty)
        {
            target.language = inferLanguageFromSources(target.sources);
        }
        
        // Parse optional fields
        
        if (decl.hasField("deps"))
        {
            auto depsField = decl.getField("deps");
            auto depsResult = depsField.value.asStringArray();
            if (depsResult.isErr)
            {
                return error!(Target)(decl, "Field 'deps' must be an array of strings");
            }
            target.deps = depsResult.unwrap();
        }
        
        if (decl.hasField("flags"))
        {
            auto flagsField = decl.getField("flags");
            auto flagsResult = flagsField.value.asStringArray();
            if (flagsResult.isErr)
            {
                return error!(Target)(decl, "Field 'flags' must be an array of strings");
            }
            target.flags = flagsResult.unwrap();
        }
        
        if (decl.hasField("env"))
        {
            auto envField = decl.getField("env");
            auto envResult = envField.value.asMap();
            if (envResult.isErr)
            {
                return error!(Target)(decl, "Field 'env' must be a map of strings");
            }
            target.env = envResult.unwrap();
        }
        
        if (decl.hasField("output"))
        {
            auto outputField = decl.getField("output");
            auto outputResult = outputField.value.asString();
            if (outputResult.isErr)
            {
                return error!(Target)(decl, "Field 'output' must be a string");
            }
            target.outputPath = outputResult.unwrap();
        }
        
        if (decl.hasField("includes"))
        {
            auto includesField = decl.getField("includes");
            auto includesResult = includesField.value.asStringArray();
            if (includesResult.isErr)
            {
                return error!(Target)(decl, "Field 'includes' must be an array of strings");
            }
            target.includes = includesResult.unwrap();
        }
        
        // Parse language-specific configuration
        if (decl.hasField("config"))
        {
            auto configField = decl.getField("config");
            if (configField.value.kind != ExpressionValue.Kind.Map)
            {
                return error!(Target)(decl, "Field 'config' must be a map");
            }
            
            try
            {
                import std.json : JSONValue, toJSON;
                // Convert ExpressionValue to JSONValue recursively
                JSONValue jsonConfig = expressionValueToJSON(configField.value);
                
                // Store config keyed by language name for flexibility
                string configKey = target.language == TargetLanguage.Generic ? 
                                   "config" : target.language.to!string.toLower;
                target.langConfig[configKey] = jsonConfig.toJSON();
            }
            catch (Exception e)
            {
                return error!(Target)(decl, "Failed to parse config: " ~ e.msg);
            }
        }
        
        return Ok!(Target, BuildError)(target);
    }
    
    /// Convert ExpressionValue to JSONValue recursively
    private JSONValue expressionValueToJSON(const ref ExpressionValue value) const
    {
        import std.json : JSONValue;
        
        final switch (value.kind)
        {
            case ExpressionValue.Kind.String:
                return JSONValue(value.stringValue.value);
            case ExpressionValue.Kind.Number:
                return JSONValue(value.numberValue.value);
            case ExpressionValue.Kind.Identifier:
                // Treat identifiers as strings (for true/false/null we keep as strings)
                string idName = value.identifierValue.name;
                if (idName == "true")
                    return JSONValue(true);
                else if (idName == "false")
                    return JSONValue(false);
                else if (idName == "null")
                    return JSONValue(null);
                else
                    return JSONValue(idName);
            case ExpressionValue.Kind.Array:
                JSONValue[] arr;
                foreach (elem; value.arrayValue.elements)
                {
                    arr ~= expressionValueToJSON(elem);
                }
                return JSONValue(arr);
            case ExpressionValue.Kind.Map:
                JSONValue obj = parseJSON("{}");
                foreach (key, val; value.mapValue.pairs)
                {
                    obj[key] = expressionValueToJSON(val);
                }
                return obj;
        }
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
    
    /// Parse language from expression - delegates to centralized registry
    private TargetLanguage parseLanguage(const ref ExpressionValue value) const
    {
        if (value.kind != ExpressionValue.Kind.Identifier)
            return TargetLanguage.Generic;
        
        string langName = value.identifierValue.name;
        return parseLanguageName(langName);
    }
    
    /// Infer language from source file extensions - delegates to centralized registry
    private TargetLanguage inferLanguageFromSources(string[] sources)
    {
        import std.path : extension;
        
        if (sources.empty)
            return TargetLanguage.Generic;
        
        string ext = extension(sources[0]);
        return inferLanguageFromExtension(ext);
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
/// Parse result containing both targets and repositories
struct ParseResult
{
    Target[] targets;
    import repository.types : RepositoryRule;
    RepositoryRule[] repositories;
}

Result!(ParseResult, BuildError) parseDSL(string source, string filePath, string workspaceRoot)
{
    // Lex
    auto lexResult = lex(source, filePath);
    if (lexResult.isErr)
        return Err!(ParseResult, BuildError)(lexResult.unwrapErr());
    
    auto tokens = lexResult.unwrap();
    
    // Parse
    auto parser = DSLParser(tokens, filePath);
    auto parseResult = parser.parse();
    if (parseResult.isErr)
        return Err!(ParseResult, BuildError)(parseResult.unwrapErr());
    
    auto ast = parseResult.unwrap();
    
    // Semantic analysis for targets
    auto analyzer = SemanticAnalyzer(workspaceRoot, filePath);
    auto targetsResult = analyzer.analyze(ast);
    if (targetsResult.isErr)
        return Err!(ParseResult, BuildError)(targetsResult.unwrapErr());
    
    // Convert repository declarations to rules
    import repository.types : RepositoryRule, RepositoryKind, ArchiveFormat;
    RepositoryRule[] repositories;
    
    foreach (ref repoDecl; ast.repositories)
    {
        RepositoryRule rule;
        rule.name = repoDecl.name;
        
        // Parse fields
        foreach (ref field; repoDecl.fields)
        {
            auto valueResult = field.value.asString();
            if (valueResult.isErr)
                continue;
            
            auto value = valueResult.unwrap();
            
            switch (field.name)
            {
                case "url":
                    rule.url = value;
                    break;
                case "integrity":
                    rule.integrity = value;
                    break;
                case "gitCommit":
                    rule.gitCommit = value;
                    rule.kind = RepositoryKind.Git;
                    break;
                case "gitTag":
                    rule.gitTag = value;
                    rule.kind = RepositoryKind.Git;
                    break;
                case "stripPrefix":
                    rule.stripPrefix = value;
                    break;
                default:
                    break;
            }
        }
        
        // Infer repository kind if not set
        if (rule.kind == RepositoryKind.init)
        {
            if (!rule.gitCommit.empty || !rule.gitTag.empty)
                rule.kind = RepositoryKind.Git;
            else if (rule.url.startsWith("/") || rule.url.startsWith("./"))
                rule.kind = RepositoryKind.Local;
            else
                rule.kind = RepositoryKind.Http;
        }
        
        repositories ~= rule;
    }
    
    ParseResult result;
    result.targets = targetsResult.unwrap();
    result.repositories = repositories;
    
    return Ok!(ParseResult, BuildError)(result);
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
    
    auto parseResult = result.unwrap();
    assert(parseResult.targets.length == 1);
    assert(parseResult.targets[0].name == "app");
    assert(parseResult.targets[0].type == TargetType.Executable);
    assert(parseResult.targets[0].language == TargetLanguage.Python);
    
    // Test repository parsing
    string dslWithRepo = `
        repository("fmt") {
            url: "https://example.com/fmt.tar.gz";
            integrity: "abc123";
        }
        
        target("app") {
            type: executable;
            sources: ["main.cpp"];
        }
    `;
    
    auto repoResult = parseDSL(dslWithRepo, "Builderfile", "/tmp");
    assert(repoResult.isOk);
    
    auto repoParseResult = repoResult.unwrap();
    assert(repoParseResult.targets.length == 1);
    assert(repoParseResult.repositories.length == 1);
    assert(repoParseResult.repositories[0].name == "fmt");
    assert(repoParseResult.repositories[0].url == "https://example.com/fmt.tar.gz");
}

