module config.scripting.interpreter;

import std.array;
import std.algorithm;
import std.conv;
import config.scripting.types;
import config.scripting.evaluator;
import config.scripting.expander;
import config.workspace.ast;
import errors;

/// Statement interpreter that executes Tier 1 programmability features
/// 
/// This interpreter:
/// - Executes variable declarations (let, const)
/// - Evaluates expressions using the Evaluator
/// - Executes control flow (if, for)
/// - Handles function and macro definitions
/// - Returns generated targets
class Interpreter
{
    private Evaluator evaluator;
    private MacroExpander expander;
    private TargetDecl[] generatedTargets;
    
    this() @system
    {
        evaluator = new Evaluator();
        expander = new MacroExpander(evaluator);
        generatedTargets = [];
    }
    
    /// Execute program (list of statements) and return generated targets
    Result!(TargetDecl[], BuildError) execute(Stmt[] statements) @system
    {
        foreach (stmt; statements)
        {
            auto result = executeStatement(stmt);
            if (result.isErr)
                return Result!(TargetDecl[], BuildError).err(result.unwrapErr());
        }
        
        return Result!(TargetDecl[], BuildError).ok(generatedTargets);
    }
    
    /// Execute single statement
    private Result!BuildError executeStatement(Stmt stmt) @system
    {
        if (auto varDecl = cast(VarDecl)stmt)
            return executeVarDecl(varDecl);
        else if (auto funcDecl = cast(FunctionDecl)stmt)
            return executeFunctionDecl(funcDecl);
        else if (auto macroDecl = cast(MacroDecl)stmt)
            return executeMacroDecl(macroDecl);
        else if (auto ifStmt = cast(IfStmt)stmt)
            return executeIfStmt(ifStmt);
        else if (auto forStmt = cast(ForStmt)stmt)
            return executeForStmt(forStmt);
        else if (auto returnStmt = cast(ReturnStmt)stmt)
            return executeReturnStmt(returnStmt);
        else if (auto importStmt = cast(ImportStmt)stmt)
            return executeImportStmt(importStmt);
        else if (auto targetStmt = cast(TargetStmt)stmt)
            return executeTargetStmt(targetStmt);
        else if (auto exprStmt = cast(ExprStmt)stmt)
            return executeExprStmt(exprStmt);
        else if (auto blockStmt = cast(BlockStmt)stmt)
            return executeBlockStmt(blockStmt);
        else
            return err("Unknown statement type");
    }
    
    /// Execute variable declaration
    private Result!BuildError executeVarDecl(VarDecl stmt) @system
    {
        // Evaluate initializer
        auto valueResult = evaluateExpr(stmt.initializer);
        if (valueResult.isErr)
            return Result!BuildError.err(valueResult.unwrapErr());
        
        // Define variable
        return evaluator.defineVariable(stmt.name, valueResult.unwrap(), stmt.isConst);
    }
    
    /// Execute function declaration
    private Result!BuildError executeFunctionDecl(FunctionDecl stmt) @system
    {
        // For now, store function definition (full implementation requires closure support)
        // This is a placeholder for Tier 1 MVP
        return Result!BuildError.ok();
    }
    
    /// Execute macro declaration
    private Result!BuildError executeMacroDecl(MacroDecl stmt) @system
    {
        // Register macro with expander
        // Convert Stmt[] to Statement[] (old format)
        Statement[] body;
        // TODO: Convert body statements
        
        return expander.define(stmt.name, stmt.parameters, body);
    }
    
    /// Execute if statement
    private Result!BuildError executeIfStmt(IfStmt stmt) @system
    {
        // Evaluate condition
        auto conditionResult = evaluateExpr(stmt.condition);
        if (conditionResult.isErr)
            return Result!BuildError.err(conditionResult.unwrapErr());
        
        bool condition = conditionResult.unwrap().toBool();
        
        // Execute appropriate branch
        if (condition)
        {
            foreach (s; stmt.thenBranch)
            {
                auto result = executeStatement(s);
                if (result.isErr)
                    return result;
            }
        }
        else if (stmt.elseBranch.length > 0)
        {
            foreach (s; stmt.elseBranch)
            {
                auto result = executeStatement(s);
                if (result.isErr)
                    return result;
            }
        }
        
        return Result!BuildError.ok();
    }
    
    /// Execute for loop
    private Result!BuildError executeForStmt(ForStmt stmt) @system
    {
        // Evaluate iterable
        auto iterableResult = evaluateExpr(stmt.iterable);
        if (iterableResult.isErr)
            return Result!BuildError.err(iterableResult.unwrapErr());
        
        auto iterable = iterableResult.unwrap();
        
        // Check if iterable is array
        if (!iterable.isArray())
        {
            auto error = new ParseError("For loop requires an array to iterate over", null);
            return Result!BuildError.err(error);
        }
        
        auto array = iterable.asArray();
        
        // Enter new scope for loop
        evaluator.enterScope();
        scope(exit) evaluator.exitScope();
        
        // Iterate over array
        foreach (element; array)
        {
            // Bind loop variable
            auto defineResult = evaluator.defineVariable(stmt.variable, element, false);
            if (defineResult.isErr)
                return defineResult;
            
            // Execute loop body
            foreach (s; stmt.body)
            {
                auto result = executeStatement(s);
                if (result.isErr)
                    return result;
            }
        }
        
        return Result!BuildError.ok();
    }
    
    /// Execute return statement
    private Result!BuildError executeReturnStmt(ReturnStmt stmt) @system
    {
        // Return statements not yet fully supported in MVP
        return Result!BuildError.ok();
    }
    
    /// Execute import statement (Tier 2 - D macros)
    private Result!BuildError executeImportStmt(ImportStmt stmt) @system
    {
        // Import statements for Tier 2 macros - not yet implemented
        return Result!BuildError.ok();
    }
    
    /// Execute target statement
    private Result!BuildError executeTargetStmt(TargetStmt stmt) @system
    {
        // Add target to generated targets list
        generatedTargets ~= stmt.target;
        return Result!BuildError.ok();
    }
    
    /// Execute expression statement
    private Result!BuildError executeExprStmt(ExprStmt stmt) @system
    {
        // Evaluate expression (for side effects, like macro calls)
        auto result = evaluateExpr(stmt.expression);
        if (result.isErr)
            return Result!BuildError.err(result.unwrapErr());
        
        return Result!BuildError.ok();
    }
    
    /// Execute block statement
    private Result!BuildError executeBlockStmt(BlockStmt stmt) @system
    {
        // Enter new scope
        evaluator.enterScope();
        scope(exit) evaluator.exitScope();
        
        // Execute all statements in block
        foreach (s; stmt.statements)
        {
            auto result = executeStatement(s);
            if (result.isErr)
                return result;
        }
        
        return Result!BuildError.ok();
    }
    
    /// Evaluate expression (bridge between Expr and Value)
    private Result!(Value, BuildError) evaluateExpr(Expr expr) @system
    {
        if (auto litExpr = cast(LiteralExpr)expr)
        {
            // Evaluate literal using existing evaluator
            return evaluator.evaluate(litExpr.value);
        }
        else if (auto binaryExpr = cast(BinaryExpr)expr)
        {
            auto leftResult = evaluateExpr(binaryExpr.left);
            if (leftResult.isErr)
                return leftResult;
            
            auto rightResult = evaluateExpr(binaryExpr.right);
            if (rightResult.isErr)
                return rightResult;
            
            return evaluator.evaluateBinary(binaryExpr.operator, leftResult.unwrap(), rightResult.unwrap());
        }
        else if (auto unaryExpr = cast(UnaryExpr)expr)
        {
            auto operandResult = evaluateExpr(unaryExpr.operand);
            if (operandResult.isErr)
                return operandResult;
            
            return evaluator.evaluateUnary(unaryExpr.operator, operandResult.unwrap());
        }
        else if (auto callExpr = cast(CallExpr)expr)
        {
            // Evaluate arguments
            Value[] args;
            foreach (arg; callExpr.arguments)
            {
                auto argResult = evaluateExpr(arg);
                if (argResult.isErr)
                    return Result!(Value, BuildError).err(argResult.unwrapErr());
                args ~= argResult.unwrap();
            }
            
            return evaluator.evaluateCall(callExpr.callee, args);
        }
        else if (auto indexExpr = cast(IndexExpr)expr)
        {
            auto objectResult = evaluateExpr(indexExpr.object);
            if (objectResult.isErr)
                return objectResult;
            
            auto indexResult = evaluateExpr(indexExpr.index);
            if (indexResult.isErr)
                return indexResult;
            
            return evaluator.evaluateIndex(objectResult.unwrap(), indexResult.unwrap());
        }
        else if (auto sliceExpr = cast(SliceExpr)expr)
        {
            auto objectResult = evaluateExpr(sliceExpr.object);
            if (objectResult.isErr)
                return objectResult;
            
            Value start = Value.makeNull();
            if (sliceExpr.start)
            {
                auto startResult = evaluateExpr(sliceExpr.start);
                if (startResult.isErr)
                    return startResult;
                start = startResult.unwrap();
            }
            
            Value end = Value.makeNull();
            if (sliceExpr.end)
            {
                auto endResult = evaluateExpr(sliceExpr.end);
                if (endResult.isErr)
                    return endResult;
                end = endResult.unwrap();
            }
            
            return evaluator.evaluateSlice(objectResult.unwrap(), start, end);
        }
        else if (auto ternaryExpr = cast(TernaryExpr)expr)
        {
            auto conditionResult = evaluateExpr(ternaryExpr.condition);
            if (conditionResult.isErr)
                return conditionResult;
            
            if (conditionResult.unwrap().toBool())
            {
                return evaluateExpr(ternaryExpr.trueExpr);
            }
            else
            {
                return evaluateExpr(ternaryExpr.falseExpr);
            }
        }
        else
        {
            auto error = new ParseError("Unsupported expression type for evaluation", null);
            return Result!(Value, BuildError).err(error);
        }
    }
    
    // Helper methods
    
    private Result!BuildError err(string msg) @system
    {
        auto error = new ParseError(msg, null);
        return Result!BuildError.err(error);
    }
}

