module config.parsing.exprparser;

import std.array;
import std.algorithm;
import std.conv;
import config.parsing.lexer;
import config.workspace.ast;
import config.workspace.expr;
import errors;

/// Expression parser using Pratt parsing (operator precedence climbing)
/// 
/// This is the SINGLE SOURCE OF TRUTH for all expression parsing in Builder.
/// Supports both simple literals and full programmability features:
/// - Literals: strings, numbers, booleans, arrays, maps
/// - Operators: +, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, !
/// - Function calls: func(args)
/// - Indexing: array[index], map[key]
/// - Slicing: array[start:end]
/// - Member access: object.member
/// - Ternary: condition ? true : false
/// - Lambdas: |param| expr
class ExprParser
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
    
    /// Parse expression (returns new Expr AST)
    Result!(Expr, BuildError) parse() @system
    {
        return parseExpression(0);
    }
    
    /// Parse expression and convert to ExpressionValue (for existing code)
    /// This bridges between the new Expr AST and old ExpressionValue AST
    Result!(ExpressionValue, BuildError) parseAsExpressionValue() @system
    {
        auto exprResult = parsePrimary();
        if (exprResult.isErr)
            return Result!(ExpressionValue, BuildError).err(exprResult.unwrapErr());
        
        auto expr = exprResult.unwrap();
        
        // Convert Expr to ExpressionValue
        if (auto litExpr = cast(LiteralExpr)expr)
        {
            return Result!(ExpressionValue, BuildError).ok(litExpr.value);
        }
        
        // For non-literals, we need to evaluate them (future work)
        // For now, just return error
        return error!(ExpressionValue)("Complex expressions not yet supported in target fields");
    }
    
    /// Get current position (for external synchronization)
    size_t position() const pure nothrow @nogc @safe
    {
        return current;
    }
    
    /// Parse expression with minimum precedence (Pratt parsing)
    private Result!(Expr, BuildError) parseExpression(int minPrecedence) @system
    {
        // Parse primary (left-hand side)
        auto leftResult = parsePrimary();
        if (leftResult.isErr)
            return leftResult;
        
        auto left = leftResult.unwrap();
        
        // Parse operators with higher precedence
        while (!isAtEnd())
        {
            auto token = peek();
            
            // Check for binary operators
            if (isBinaryOp(token.type))
            {
                int precedence = getPrecedence(token.type);
                if (precedence < minPrecedence)
                    break;
                
                advance();  // Consume operator
                
                // Parse right-hand side with higher precedence
                auto rightResult = parseExpression(precedence + (isRightAssociative(token.type) ? 0 : 1));
                if (rightResult.isErr)
                    return Result!(Expr, BuildError).err(rightResult.unwrapErr());
                
                left = new BinaryExpr(left, token.value, rightResult.unwrap(), token.line, token.column);
            }
            // Check for ternary operator
            else if (token.type == TokenType.Question)
            {
                int precedence = 3;  // Ternary has low precedence
                if (precedence < minPrecedence)
                    break;
                
                advance();  // Consume ?
                
                auto trueExprResult = parseExpression(0);
                if (trueExprResult.isErr)
                    return Result!(Expr, BuildError).err(trueExprResult.unwrapErr());
                
                if (!expect(TokenType.Colon))
                    return error!Expr("Expected ':' in ternary operator");
                
                auto falseExprResult = parseExpression(precedence);
                if (falseExprResult.isErr)
                    return Result!(Expr, BuildError).err(falseExprResult.unwrapErr());
                
                left = new TernaryExpr(left, trueExprResult.unwrap(), falseExprResult.unwrap(), token.line, token.column);
            }
            // Check for postfix operators
            else if (token.type == TokenType.LeftBracket)
            {
                advance();  // Consume [
                
                // Check for slice [start:end]
                if (peek().type == TokenType.Colon)
                {
                    advance();  // Consume :
                    auto endResult = parseExpression(0);
                    if (endResult.isErr)
                        return Result!(Expr, BuildError).err(endResult.unwrapErr());
                    
                    if (!expect(TokenType.RightBracket))
                        return error!Expr("Expected ']' after slice");
                    
                    left = new SliceExpr(left, null, endResult.unwrap(), token.line, token.column);
                }
                else
                {
                    auto indexResult = parseExpression(0);
                    if (indexResult.isErr)
                        return Result!(Expr, BuildError).err(indexResult.unwrapErr());
                    
                    // Check for slice [start:end]
                    if (peek().type == TokenType.Colon)
                    {
                        advance();  // Consume :
                        
                        Expr end = null;
                        if (peek().type != TokenType.RightBracket)
                        {
                            auto endResult = parseExpression(0);
                            if (endResult.isErr)
                                return Result!(Expr, BuildError).err(endResult.unwrapErr());
                            end = endResult.unwrap();
                        }
                        
                        if (!expect(TokenType.RightBracket))
                            return error!Expr("Expected ']' after slice");
                        
                        left = new SliceExpr(left, indexResult.unwrap(), end, token.line, token.column);
                    }
                    else
                    {
                        if (!expect(TokenType.RightBracket))
                            return error!Expr("Expected ']' after index");
                        
                        left = new IndexExpr(left, indexResult.unwrap(), token.line, token.column);
                    }
                }
            }
            else if (token.type == TokenType.Dot)
            {
                advance();  // Consume .
                
                if (peek().type != TokenType.Identifier)
                    return error!Expr("Expected member name after '.'");
                
                auto member = advance();
                left = new MemberExpr(left, member.value, token.line, token.column);
            }
            else if (token.type == TokenType.LeftParen && cast(LiteralExpr)left && 
                    (cast(LiteralExpr)left).value.kind == ExpressionValue.Kind.Identifier)
            {
                // Function call
                auto literalExpr = cast(LiteralExpr)left;
                string funcName = literalExpr.value.identifierValue.name;
                
                advance();  // Consume (
                
                Expr[] args;
                if (peek().type != TokenType.RightParen)
                {
                    do
                    {
                        if (peek().type == TokenType.Comma)
                            advance();
                        
                        auto argResult = parseExpression(0);
                        if (argResult.isErr)
                            return Result!(Expr, BuildError).err(argResult.unwrapErr());
                        args ~= argResult.unwrap();
                    } while (peek().type == TokenType.Comma);
                }
                
                if (!expect(TokenType.RightParen))
                    return error!Expr("Expected ')' after function arguments");
                
                left = new CallExpr(funcName, args, token.line, token.column);
            }
            else
            {
                break;
            }
        }
        
        return Result!(Expr, BuildError).ok(left);
    }
    
    /// Parse primary expression (literals, identifiers, unary, etc.)
    private Result!(Expr, BuildError) parsePrimary() @system
    {
        auto token = peek();
        
        // Unary operators
        if (token.type == TokenType.Minus || token.type == TokenType.Bang)
        {
            advance();
            auto operandResult = parsePrimary();
            if (operandResult.isErr)
                return operandResult;
            
            return Result!(Expr, BuildError).ok(
                new UnaryExpr(token.value, operandResult.unwrap(), token.line, token.column)
            );
        }
        
        // Parenthesized expression
        if (token.type == TokenType.LeftParen)
        {
            advance();
            auto exprResult = parseExpression(0);
            if (exprResult.isErr)
                return exprResult;
            
            if (!expect(TokenType.RightParen))
                return error!Expr("Expected ')' after expression");
            
            return exprResult;
        }
        
        // Lambda expression |param| expr
        if (token.type == TokenType.Pipe)
        {
            advance();  // Consume |
            
            string[] params;
            if (peek().type != TokenType.Pipe)
            {
                do
                {
                    if (peek().type == TokenType.Comma)
                        advance();
                    
                    if (peek().type != TokenType.Identifier)
                        return error!Expr("Expected parameter name in lambda");
                    params ~= advance().value;
                } while (peek().type == TokenType.Comma);
            }
            
            if (!expect(TokenType.Pipe))
                return error!Expr("Expected '|' after lambda parameters");
            
            auto bodyResult = parseExpression(0);
            if (bodyResult.isErr)
                return bodyResult;
            
            return Result!(Expr, BuildError).ok(
                new LambdaExpr(params, bodyResult.unwrap(), token.line, token.column)
            );
        }
        
        // Literals
        if (token.type == TokenType.String)
        {
            advance();
            return Result!(Expr, BuildError).ok(
                new LiteralExpr(
                    ExpressionValue.fromString(token.value, token.line, token.column),
                    token.line, token.column
                )
            );
        }
        
        if (token.type == TokenType.Number)
        {
            advance();
            return Result!(Expr, BuildError).ok(
                new LiteralExpr(
                    ExpressionValue.fromNumber(token.value.to!long, token.line, token.column),
                    token.line, token.column
                )
            );
        }
        
        if (token.type == TokenType.True || token.type == TokenType.False)
        {
            advance();
            return Result!(Expr, BuildError).ok(
                new LiteralExpr(
                    ExpressionValue.fromIdentifier(token.value, token.line, token.column),
                    token.line, token.column
                )
            );
        }
        
        if (token.type == TokenType.Null)
        {
            advance();
            return Result!(Expr, BuildError).ok(
                new LiteralExpr(
                    ExpressionValue.fromIdentifier("null", token.line, token.column),
                    token.line, token.column
                )
            );
        }
        
        if (token.type == TokenType.Identifier)
        {
            advance();
            return Result!(Expr, BuildError).ok(
                new LiteralExpr(
                    ExpressionValue.fromIdentifier(token.value, token.line, token.column),
                    token.line, token.column
                )
            );
        }
        
        // Array literal
        if (token.type == TokenType.LeftBracket)
        {
            return parseArrayLiteral();
        }
        
        // Map literal
        if (token.type == TokenType.LeftBrace)
        {
            return parseMapLiteral();
        }
        
        return error!Expr("Expected expression");
    }
    
    /// Parse array literal
    private Result!(Expr, BuildError) parseArrayLiteral() @system
    {
        size_t line = peek().line;
        size_t col = peek().column;
        
        if (!expect(TokenType.LeftBracket))
            return error!Expr("Expected '['");
        
        ExpressionValue[] elements;
        
        if (peek().type != TokenType.RightBracket)
        {
            do
            {
                if (peek().type == TokenType.Comma)
                    advance();
                
                auto elemResult = parseExpression(0);
                if (elemResult.isErr)
                    return Result!(Expr, BuildError).err(elemResult.unwrapErr());
                
                // Convert Expr to ExpressionValue (must be literal for now)
                auto expr = elemResult.unwrap();
                if (auto litExpr = cast(LiteralExpr)expr)
                {
                    elements ~= litExpr.value;
                }
                else
                {
                    return error!Expr("Array elements must be literals (for now)");
                }
            } while (peek().type == TokenType.Comma);
        }
        
        if (!expect(TokenType.RightBracket))
            return error!Expr("Expected ']' after array elements");
        
        return Result!(Expr, BuildError).ok(
            new LiteralExpr(
                ExpressionValue.fromArray(elements, line, col),
                line, col
            )
        );
    }
    
    /// Parse map literal
    private Result!(Expr, BuildError) parseMapLiteral() @system
    {
        size_t line = peek().line;
        size_t col = peek().column;
        
        if (!expect(TokenType.LeftBrace))
            return error!Expr("Expected '{'");
        
        ExpressionValue[string] pairs;
        
        if (peek().type != TokenType.RightBrace)
        {
            do
            {
                if (peek().type == TokenType.Comma)
                    advance();
                
                if (peek().type != TokenType.Identifier && peek().type != TokenType.String)
                    return error!Expr("Expected key in map");
                
                string key = advance().value;
                
                if (!expect(TokenType.Colon))
                    return error!Expr("Expected ':' after map key");
                
                auto valueResult = parseExpression(0);
                if (valueResult.isErr)
                    return Result!(Expr, BuildError).err(valueResult.unwrapErr());
                
                // Convert Expr to ExpressionValue
                auto expr = valueResult.unwrap();
                if (auto litExpr = cast(LiteralExpr)expr)
                {
                    pairs[key] = litExpr.value;
                }
                else
                {
                    return error!Expr("Map values must be literals (for now)");
                }
            } while (peek().type == TokenType.Comma);
        }
        
        if (!expect(TokenType.RightBrace))
            return error!Expr("Expected '}' after map pairs");
        
        return Result!(Expr, BuildError).ok(
            new LiteralExpr(
                ExpressionValue.fromMap(pairs, line, col),
                line, col
            )
        );
    }
    
    // Operator precedence (higher = tighter binding)
    private int getPrecedence(TokenType type) pure nothrow @nogc @safe
    {
        switch (type)
        {
            case TokenType.PipePipe:
                return 4;
            case TokenType.AmpAmp:
                return 5;
            case TokenType.EqualEqual:
            case TokenType.BangEqual:
                return 6;
            case TokenType.Less:
            case TokenType.LessEqual:
            case TokenType.Greater:
            case TokenType.GreaterEqual:
                return 7;
            case TokenType.Plus:
            case TokenType.Minus:
                return 8;
            case TokenType.Star:
            case TokenType.Slash:
            case TokenType.Percent:
                return 9;
            default:
                return 0;
        }
    }
    
    private bool isRightAssociative(TokenType type) pure nothrow @nogc @safe
    {
        return false;  // All operators are left-associative for now
    }
    
    private bool isBinaryOp(TokenType type) pure nothrow @nogc @safe
    {
        switch (type)
        {
            case TokenType.Plus:
            case TokenType.Minus:
            case TokenType.Star:
            case TokenType.Slash:
            case TokenType.Percent:
            case TokenType.EqualEqual:
            case TokenType.BangEqual:
            case TokenType.Less:
            case TokenType.LessEqual:
            case TokenType.Greater:
            case TokenType.GreaterEqual:
            case TokenType.AmpAmp:
            case TokenType.PipePipe:
                return true;
            default:
                return false;
        }
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
    
    private Result!(T, BuildError) error(T)(string message) @system
    {
        auto token = peek();
        auto err = new ParseError(filePath, message, ErrorCode.ParseFailed);
        err.line = token.line;
        err.column = token.column;
        return Result!(T, BuildError).err(err);
    }
}

