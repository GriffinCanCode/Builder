module config.parsing.stmtparser;

import std.array;
import std.algorithm;
import std.conv;
import config.parsing.lexer;
import config.parsing.exprparser;
import config.workspace.ast;
import config.workspace.expr;
import config.workspace.stmt;
import errors;

/// Statement parser for programmability features
class StmtParser
{
    private Token[] tokens;
    private size_t current;
    private string filePath;
    
    this(Token[] tokens, string filePath = "") pure nothrow @safe
    {
        this.tokens = tokens;
        this.current = 0;
        this.filePath = filePath;
    }
    
    /// Parse all statements (program)
    Result!(Stmt[], BuildError) parseProgram() @system
    {
        Stmt[] statements;
        
        while (!isAtEnd())
        {
            auto stmtResult = parseStatement();
            if (stmtResult.isErr)
                return Result!(Stmt[], BuildError).err(stmtResult.unwrapErr());
            
            statements ~= stmtResult.unwrap();
        }
        
        return Result!(Stmt[], BuildError).ok(statements);
    }
    
    /// Parse single statement
    Result!(Stmt, BuildError) parseStatement() @system
    {
        auto token = peek();
        
        switch (token.type)
        {
            case TokenType.Let:
            case TokenType.Const:
                return parseVarDecl();
            
            case TokenType.Fn:
                return parseFunctionDecl();
            
            case TokenType.Macro:
                return parseMacroDecl();
            
            case TokenType.If:
                return parseIfStmt();
            
            case TokenType.For:
                return parseForStmt();
            
            case TokenType.Return:
                return parseReturnStmt();
            
            case TokenType.Import:
                return parseImportStmt();
            
            case TokenType.Target:
                return parseTargetStmt();
            
            case TokenType.LeftBrace:
                return parseBlockStmt();
            
            default:
                // Try parsing as expression statement
                return parseExprStmt();
        }
    }
    
    /// Parse variable declaration (let x = expr; or const x = expr;)
    private Result!(Stmt, BuildError) parseVarDecl() @system
    {
        auto token = advance();  // let or const
        bool isConst = (token.type == TokenType.Const);
        
        if (peek().type != TokenType.Identifier)
            return error!Stmt("Expected variable name after " ~ (isConst ? "const" : "let"));
        
        string name = advance().value;
        
        if (!expect(TokenType.Equal))
            return error!Stmt("Expected '=' in variable declaration");
        
        auto exprResult = parseExpr();
        if (exprResult.isErr)
            return Result!(Stmt, BuildError).err(exprResult.unwrapErr());
        
        expectSemicolon();  // Optional
        
        return Result!(Stmt, BuildError).ok(
            new VarDecl(name, exprResult.unwrap(), isConst, token.line, token.column)
        );
    }
    
    /// Parse function declaration
    private Result!(Stmt, BuildError) parseFunctionDecl() @system
    {
        auto token = advance();  // fn
        
        if (peek().type != TokenType.Identifier)
            return error!Stmt("Expected function name");
        
        string name = advance().value;
        
        if (!expect(TokenType.LeftParen))
            return error!Stmt("Expected '(' after function name");
        
        Parameter[] parameters;
        if (peek().type != TokenType.RightParen)
        {
            do
            {
                if (peek().type == TokenType.Comma)
                    advance();
                
                if (peek().type != TokenType.Identifier)
                    return error!Stmt("Expected parameter name");
                
                Parameter param;
                param.name = advance().value;
                param.hasDefault = false;
                
                // Check for default value
                if (peek().type == TokenType.Equal)
                {
                    advance();
                    auto defaultResult = parseExpr();
                    if (defaultResult.isErr)
                        return Result!(Stmt, BuildError).err(defaultResult.unwrapErr());
                    
                    param.hasDefault = true;
                    param.defaultValue = defaultResult.unwrap();
                }
                
                parameters ~= param;
            } while (peek().type == TokenType.Comma);
        }
        
        if (!expect(TokenType.RightParen))
            return error!Stmt("Expected ')' after parameters");
        
        if (!expect(TokenType.LeftBrace))
            return error!Stmt("Expected '{' before function body");
        
        auto bodyResult = parseBlock();
        if (bodyResult.isErr)
            return Result!(Stmt, BuildError).err(bodyResult.unwrapErr());
        
        return Result!(Stmt, BuildError).ok(
            new FunctionDecl(name, parameters, bodyResult.unwrap(), token.line, token.column)
        );
    }
    
    /// Parse macro declaration
    private Result!(Stmt, BuildError) parseMacroDecl() @system
    {
        auto token = advance();  // macro
        
        if (peek().type != TokenType.Identifier)
            return error!Stmt("Expected macro name");
        
        string name = advance().value;
        
        if (!expect(TokenType.LeftParen))
            return error!Stmt("Expected '(' after macro name");
        
        string[] parameters;
        if (peek().type != TokenType.RightParen)
        {
            do
            {
                if (peek().type == TokenType.Comma)
                    advance();
                
                if (peek().type != TokenType.Identifier)
                    return error!Stmt("Expected parameter name");
                
                parameters ~= advance().value;
            } while (peek().type == TokenType.Comma);
        }
        
        if (!expect(TokenType.RightParen))
            return error!Stmt("Expected ')' after parameters");
        
        if (!expect(TokenType.LeftBrace))
            return error!Stmt("Expected '{' before macro body");
        
        auto bodyResult = parseBlock();
        if (bodyResult.isErr)
            return Result!(Stmt, BuildError).err(bodyResult.unwrapErr());
        
        return Result!(Stmt, BuildError).ok(
            new MacroDecl(name, parameters, bodyResult.unwrap(), token.line, token.column)
        );
    }
    
    /// Parse if statement
    private Result!(Stmt, BuildError) parseIfStmt() @system
    {
        auto token = advance();  // if
        
        if (!expect(TokenType.LeftParen))
            return error!Stmt("Expected '(' after 'if'");
        
        auto conditionResult = parseExpr();
        if (conditionResult.isErr)
            return Result!(Stmt, BuildError).err(conditionResult.unwrapErr());
        
        if (!expect(TokenType.RightParen))
            return error!Stmt("Expected ')' after condition");
        
        if (!expect(TokenType.LeftBrace))
            return error!Stmt("Expected '{' after condition");
        
        auto thenResult = parseBlock();
        if (thenResult.isErr)
            return Result!(Stmt, BuildError).err(thenResult.unwrapErr());
        
        Stmt[] elseBranch;
        if (peek().type == TokenType.Else)
        {
            advance();  // else
            
            if (peek().type == TokenType.If)
            {
                // else if
                auto elseIfResult = parseIfStmt();
                if (elseIfResult.isErr)
                    return Result!(Stmt, BuildError).err(elseIfResult.unwrapErr());
                elseBranch = [elseIfResult.unwrap()];
            }
            else
            {
                if (!expect(TokenType.LeftBrace))
                    return error!Stmt("Expected '{' after 'else'");
                
                auto elseResult = parseBlock();
                if (elseResult.isErr)
                    return Result!(Stmt, BuildError).err(elseResult.unwrapErr());
                elseBranch = elseResult.unwrap();
            }
        }
        
        return Result!(Stmt, BuildError).ok(
            new IfStmt(conditionResult.unwrap(), thenResult.unwrap(), elseBranch, token.line, token.column)
        );
    }
    
    /// Parse for loop
    private Result!(Stmt, BuildError) parseForStmt() @system
    {
        auto token = advance();  // for
        
        if (peek().type != TokenType.Identifier)
            return error!Stmt("Expected loop variable after 'for'");
        
        string variable = advance().value;
        
        if (!expect(TokenType.In))
            return error!Stmt("Expected 'in' after loop variable");
        
        auto iterableResult = parseExpr();
        if (iterableResult.isErr)
            return Result!(Stmt, BuildError).err(iterableResult.unwrapErr());
        
        if (!expect(TokenType.LeftBrace))
            return error!Stmt("Expected '{' before loop body");
        
        auto bodyResult = parseBlock();
        if (bodyResult.isErr)
            return Result!(Stmt, BuildError).err(bodyResult.unwrapErr());
        
        return Result!(Stmt, BuildError).ok(
            new ForStmt(variable, iterableResult.unwrap(), bodyResult.unwrap(), token.line, token.column)
        );
    }
    
    /// Parse return statement
    private Result!(Stmt, BuildError) parseReturnStmt() @system
    {
        auto token = advance();  // return
        
        Expr value = null;
        if (peek().type != TokenType.Semicolon && !isAtEnd())
        {
            auto valueResult = parseExpr();
            if (valueResult.isErr)
                return Result!(Stmt, BuildError).err(valueResult.unwrapErr());
            value = valueResult.unwrap();
        }
        
        expectSemicolon();
        
        return Result!(Stmt, BuildError).ok(
            new ReturnStmt(value, token.line, token.column)
        );
    }
    
    /// Parse import statement
    private Result!(Stmt, BuildError) parseImportStmt() @system
    {
        auto token = advance();  // import
        
        if (peek().type != TokenType.Identifier && peek().type != TokenType.String)
            return error!Stmt("Expected module path after 'import'");
        
        string modulePath = advance().value;
        
        expectSemicolon();
        
        return Result!(Stmt, BuildError).ok(
            new ImportStmt(modulePath, token.line, token.column)
        );
    }
    
    /// Parse target statement (delegate to existing parser)
    private Result!(Stmt, BuildError) parseTargetStmt() @system
    {
        // This needs to integrate with existing target parsing
        // For now, return placeholder
        return error!Stmt("Target parsing not yet integrated");
    }
    
    /// Parse block statement
    private Result!(Stmt, BuildError) parseBlockStmt() @system
    {
        auto token = peek();
        
        if (!expect(TokenType.LeftBrace))
            return error!Stmt("Expected '{'");
        
        auto stmtsResult = parseBlock();
        if (stmtsResult.isErr)
            return Result!(Stmt, BuildError).err(stmtsResult.unwrapErr());
        
        return Result!(Stmt, BuildError).ok(
            new BlockStmt(stmtsResult.unwrap(), token.line, token.column)
        );
    }
    
    /// Parse expression statement
    private Result!(Stmt, BuildError) parseExprStmt() @system
    {
        auto token = peek();
        
        auto exprResult = parseExpr();
        if (exprResult.isErr)
            return Result!(Stmt, BuildError).err(exprResult.unwrapErr());
        
        expectSemicolon();
        
        return Result!(Stmt, BuildError).ok(
            new ExprStmt(exprResult.unwrap(), token.line, token.column)
        );
    }
    
    /// Parse block of statements (until '}')
    private Result!(Stmt[], BuildError) parseBlock() @system
    {
        Stmt[] statements;
        
        while (!isAtEnd() && peek().type != TokenType.RightBrace)
        {
            auto stmtResult = parseStatement();
            if (stmtResult.isErr)
                return Result!(Stmt[], BuildError).err(stmtResult.unwrapErr());
            
            statements ~= stmtResult.unwrap();
        }
        
        if (!expect(TokenType.RightBrace))
            return error!(Stmt[])("Expected '}' after block");
        
        return Result!(Stmt[], BuildError).ok(statements);
    }
    
    /// Parse expression (delegate to expression parser)
    private Result!(Expr, BuildError) parseExpr() @system
    {
        auto exprParser = new ExprParser(tokens[current .. $], filePath);
        auto result = exprParser.parse();
        
        if (result.isOk)
        {
            // Advance current position by how many tokens were consumed
            // For now, advance manually - in production, track token consumption
            // This is a simplification; proper implementation would need token tracking
        }
        
        return result;
    }
    
    // Helper methods
    
    private bool isAtEnd() const pure nothrow @nogc @safe
    {
        return current >= tokens.length || peek().type == TokenType.EOF;
    }
    
    private Token peek() const pure nothrow @nogc @safe
    {
        return current < tokens.length ? tokens[current] : Token(TokenType.EOF, "", 0, 0);
    }
    
    private Token advance() pure nothrow @safe
    {
        if (!isAtEnd())
            current++;
        return tokens[current - 1];
    }
    
    private bool expect(TokenType type) pure nothrow @safe
    {
        if (peek().type == type)
        {
            advance();
            return true;
        }
        return false;
    }
    
    private void expectSemicolon() pure nothrow @safe
    {
        // Semicolons are optional in our DSL
        if (peek().type == TokenType.Semicolon)
            advance();
    }
    
    private Result!(T, BuildError) error(T)(string message) @system
    {
        auto token = peek();
        auto err = new ParseError(filePath, message, ErrorCode.ParseFailed);
        err.line = token.line;
        err.column = token.column;
        return Result!(T, BuildError).err(err);
    }
}

