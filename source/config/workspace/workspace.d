module config.workspace.workspace;

import std.conv;
import std.algorithm;
import std.array;
import std.string;
import config.parsing.lexer;
import config.workspace.ast;
import config.schema.schema;
import errors;

/// Workspace-level configuration AST nodes

/// Workspace declaration
struct WorkspaceDecl
{
    string name;
    WorkspaceField[] fields;
    size_t line;
    size_t column;
    
    /// Get field by name
    const(WorkspaceField)* getField(string name) const
    {
        foreach (ref field; fields)
        {
            if (field.name == name)
                return &field;
        }
        return null;
    }
    
    /// Check if has field
    bool hasField(string name) const
    {
        return getField(name) !is null;
    }
}

/// Workspace field (similar to Field but for workspace config)
struct WorkspaceField
{
    string name;
    ExpressionValue value;
    size_t line;
    size_t column;
}

/// Root workspace file AST
struct WorkspaceFile
{
    WorkspaceDecl workspace;
    string filePath;
}

/// Parser for Builderspace files
struct WorkspaceParser
{
    private Token[] tokens;
    private size_t current;
    private string filePath;
    
    this(Token[] tokens, string filePath = "")
    {
        this.tokens = tokens;
        this.filePath = filePath;
    }
    
    /// Parse Builderspace file into AST
    Result!(WorkspaceFile, BuildError) parse()
    {
        WorkspaceFile file;
        file.filePath = filePath;
        
        auto workspaceResult = parseWorkspace();
        if (workspaceResult.isErr)
            return Err!(WorkspaceFile, BuildError)(workspaceResult.unwrapErr());
        
        file.workspace = workspaceResult.unwrap();
        
        return Ok!(WorkspaceFile, BuildError)(file);
    }
    
    /// Parse workspace declaration
    private Result!(WorkspaceDecl, BuildError) parseWorkspace()
    {
        auto token = peek();
        size_t line = token.line;
        size_t col = token.column;
        
        // Expect: workspace keyword (identifier "workspace")
        if (!check(TokenType.Identifier) || peek().value != "workspace")
        {
            return error!(WorkspaceDecl)("Expected 'workspace' keyword at start of Builderspace file");
        }
        advance();
        
        // Expect: (
        if (!match(TokenType.LeftParen))
        {
            return error!(WorkspaceDecl)("Expected '(' after 'workspace'");
        }
        
        // Expect: "name"
        if (!check(TokenType.String))
        {
            return error!(WorkspaceDecl)("Expected workspace name as string literal");
        }
        
        string name = advance().value;
        
        // Expect: )
        if (!match(TokenType.RightParen))
        {
            return error!(WorkspaceDecl)("Expected ')' after workspace name");
        }
        
        // Expect: {
        if (!match(TokenType.LeftBrace))
        {
            return error!(WorkspaceDecl)("Expected '{' to begin workspace body");
        }
        
        // Parse fields
        WorkspaceField[] fields;
        
        while (!check(TokenType.RightBrace) && !isAtEnd())
        {
            auto fieldResult = parseField();
            if (fieldResult.isErr)
                return Err!(WorkspaceDecl, BuildError)(fieldResult.unwrapErr());
            
            fields ~= fieldResult.unwrap();
        }
        
        // Expect: }
        if (!match(TokenType.RightBrace))
        {
            return error!(WorkspaceDecl)("Expected '}' to end workspace body");
        }
        
        return Ok!(WorkspaceDecl, BuildError)(WorkspaceDecl(name, fields, line, col));
    }
    
    /// Parse field assignment
    private Result!(WorkspaceField, BuildError) parseField()
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
            case TokenType.Identifier:
                fieldName = advance().value;
                break;
            default:
                return error!(WorkspaceField)("Expected field name");
        }
        
        // Expect: :
        if (!match(TokenType.Colon))
        {
            return error!(WorkspaceField)("Expected ':' after field name");
        }
        
        // Parse value
        auto valueResult = parseExpression();
        if (valueResult.isErr)
            return Err!(WorkspaceField, BuildError)(valueResult.unwrapErr());
        
        auto value = valueResult.unwrap();
        
        // Expect: ;
        if (!match(TokenType.Semicolon))
        {
            return error!(WorkspaceField)("Expected ';' after field value");
        }
        
        return Ok!(WorkspaceField, BuildError)(WorkspaceField(fieldName, value, line, col));
    }
    
    /// Parse expression (reuse from DSL parser)
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

/// Semantic analyzer for workspace configuration
struct WorkspaceAnalyzer
{
    private string workspacePath;
    
    this(string workspacePath)
    {
        this.workspacePath = workspacePath;
    }
    
    /// Analyze and apply workspace configuration to WorkspaceConfig
    Result!BuildError analyze(ref WorkspaceFile ast, ref WorkspaceConfig config)
    {
        auto decl = ast.workspace;
        
        // Parse build options
        if (decl.hasField("cacheDir"))
        {
            auto field = decl.getField("cacheDir");
            try
            {
                config.options.cacheDir = field.value.asString();
            }
            catch (Exception e)
            {
                return error("Field 'cacheDir' must be a string");
            }
        }
        
        if (decl.hasField("outputDir"))
        {
            auto field = decl.getField("outputDir");
            try
            {
                config.options.outputDir = field.value.asString();
            }
            catch (Exception e)
            {
                return error("Field 'outputDir' must be a string");
            }
        }
        
        if (decl.hasField("parallel"))
        {
            auto field = decl.getField("parallel");
            try
            {
                string val = field.value.asString().toLower;
                config.options.parallel = (val == "true" || val == "1");
            }
            catch (Exception e)
            {
                return error("Field 'parallel' must be a boolean (true/false)");
            }
        }
        
        if (decl.hasField("incremental"))
        {
            auto field = decl.getField("incremental");
            try
            {
                string val = field.value.asString().toLower;
                config.options.incremental = (val == "true" || val == "1");
            }
            catch (Exception e)
            {
                return error("Field 'incremental' must be a boolean (true/false)");
            }
        }
        
        if (decl.hasField("verbose"))
        {
            auto field = decl.getField("verbose");
            try
            {
                string val = field.value.asString().toLower;
                config.options.verbose = (val == "true" || val == "1");
            }
            catch (Exception e)
            {
                return error("Field 'verbose' must be a boolean (true/false)");
            }
        }
        
        if (decl.hasField("maxJobs"))
        {
            auto field = decl.getField("maxJobs");
            try
            {
                if (field.value.kind == ExpressionValue.Kind.Number)
                {
                    config.options.maxJobs = cast(size_t) field.value.numberValue.value;
                }
                else
                {
                    config.options.maxJobs = field.value.asString().to!size_t;
                }
            }
            catch (Exception e)
            {
                return error("Field 'maxJobs' must be a number");
            }
        }
        
        // Parse global environment
        if (decl.hasField("env"))
        {
            auto field = decl.getField("env");
            try
            {
                config.globalEnv = field.value.asMap();
            }
            catch (Exception e)
            {
                return error("Field 'env' must be a map of strings");
            }
        }
        
        return Result!BuildError.ok();
    }
    
    private Result!BuildError error(string message)
    {
        auto err = new ParseError(workspacePath, message, ErrorCode.InvalidBuildFile);
        return Result!BuildError.err(err);
    }
}

/// High-level API for parsing Builderspace files
Result!BuildError parseWorkspaceDSL(string source, string filePath, ref WorkspaceConfig config)
{
    // Lex
    auto lexResult = lex(source, filePath);
    if (lexResult.isErr)
        return Result!BuildError.err(lexResult.unwrapErr());
    
    auto tokens = lexResult.unwrap();
    
    // Parse
    auto parser = WorkspaceParser(tokens, filePath);
    auto parseResult = parser.parse();
    if (parseResult.isErr)
        return Result!BuildError.err(parseResult.unwrapErr());
    
    auto ast = parseResult.unwrap();
    
    // Semantic analysis
    auto analyzer = WorkspaceAnalyzer(filePath);
    return analyzer.analyze(ast, config);
}

/// High-level Workspace class for convenient workspace management
class Workspace
{
    private string _rootPath;
    private string _name;
    private WorkspaceConfig _config;
    
    this(string rootPath)
    {
        this._rootPath = rootPath;
        import std.path : baseName;
        this._name = baseName(rootPath);
    }
    
    /// Load workspace from directory
    static Workspace load(string path)
    {
        import std.file : exists, isDir;
        import std.path : buildPath;
        
        if (!exists(path) || !isDir(path))
            return null;
        
        auto workspace = new Workspace(path);
        
        // Try to load Builderspace file if it exists
        auto builderspacePath = buildPath(path, "Builderspace");
        if (exists(builderspacePath))
        {
            import std.file : readText;
            try
            {
                auto content = readText(builderspacePath);
                
                // Parse the workspace file
                auto lexResult = lex(content, builderspacePath);
                if (lexResult.isOk)
                {
                    auto tokens = lexResult.unwrap();
                    auto parser = WorkspaceParser(tokens, builderspacePath);
                    auto parseResult = parser.parse();
                    
                    if (parseResult.isOk)
                    {
                        auto wsFile = parseResult.unwrap();
                        workspace._name = wsFile.workspace.name;
                        
                        // Also analyze for config
                        auto analyzer = WorkspaceAnalyzer(builderspacePath);
                        analyzer.analyze(wsFile, workspace._config);
                    }
                }
            }
            catch (Exception e)
            {
                import utils.logging.logger;
                Logger.debug_("Failed to parse Builderspace file at " ~ builderspacePath ~ ": " ~ e.msg);
            }
        }
        
        return workspace;
    }
    
    /// Get workspace name
    @property string name() const
    {
        return _name;
    }
    
    /// Get workspace root path
    @property string rootPath() const
    {
        return _rootPath;
    }
    
    /// Find all Builderfiles in workspace
    string[] findBuilderfiles()
    {
        import std.file : dirEntries, SpanMode, isFile;
        import std.algorithm : filter, map;
        import std.array : array;
        import std.path : baseName, relativePath;
        import utils.files.ignore : IgnoreRegistry;
        
        try
        {
            return dirEntries(_rootPath, SpanMode.depth)
                .filter!((e) {
                    // Check if any part of the path should be ignored
                    auto relPath = relativePath(e.name, _rootPath);
                    if (IgnoreRegistry.shouldIgnorePathAny(relPath))
                        return false;
                    return e.isFile && e.name.baseName == "Builderfile";
                })
                .map!(e => e.name)
                .array;
        }
        catch (Exception ex)
        {
            import utils.logging.logger : Logger;
            Logger.debug_("Failed to find Builderfiles in " ~ _rootPath ~ ": " ~ ex.msg);
            return [];
        }
    }
    
    /// Get workspace configuration
    @property ref WorkspaceConfig config()
    {
        return _config;
    }
}

