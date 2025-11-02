module config.scripting.evaluator;

import std.conv;
import std.algorithm;
import std.array;
import std.string;
import config.scripting.types;
import config.scripting.scopemanager;
import config.scripting.builtins;
import config.workspace.ast;
import errors;

/// Expression evaluator with type checking
class Evaluator
{
    private ScopeManager scope_;
    private BuiltinRegistry builtins;
    private bool typeCheckOnly;  // If true, only check types without evaluation
    
    this() @system
    {
        scope_ = new ScopeManager();
        builtins = new BuiltinRegistry();
        typeCheckOnly = false;
    }
    
    /// Get scope manager
    ScopeManager scopeManager() pure nothrow @nogc @safe
    {
        return scope_;
    }
    
    /// Evaluate expression value from AST
    Result!(Value, BuildError) evaluate(ExpressionValue expr) @system
    {
        final switch (expr.type)
        {
            case ExpressionType.String:
                return Result!(Value, BuildError).ok(
                    Value.makeString(evaluateStringInterpolation(expr.stringValue))
                );
            
            case ExpressionType.Number:
                return Result!(Value, BuildError).ok(Value.makeNumber(expr.numberValue));
            
            case ExpressionType.Identifier:
                return evaluateIdentifier(expr.identifierValue);
            
            case ExpressionType.Array:
                return evaluateArray(expr.arrayValue);
            
            case ExpressionType.Map:
                return evaluateMap(expr.mapValue);
        }
    }
    
    /// Evaluate string with interpolation ${expr}
    private string evaluateStringInterpolation(string str) @system
    {
        import std.regex;
        
        // Pattern: ${...}
        auto pattern = regex(r"\$\{([^}]+)\}");
        
        string result = str;
        foreach (match; matchAll(str, pattern))
        {
            auto expr = match[1];
            
            // Parse and evaluate the expression
            // For now, just lookup as variable
            auto lookupResult = scope_.lookup(expr);
            if (lookupResult.isOk)
            {
                auto value = lookupResult.unwrap();
                result = result.replace(match[0], value.toString());
            }
        }
        
        return result;
    }
    
    /// Evaluate identifier (variable lookup)
    private Result!(Value, BuildError) evaluateIdentifier(string name) @system
    {
        // Check if it's a boolean literal
        if (name == "true")
            return Result!(Value, BuildError).ok(Value.makeBool(true));
        if (name == "false")
            return Result!(Value, BuildError).ok(Value.makeBool(false));
        if (name == "null")
            return Result!(Value, BuildError).ok(Value.makeNull());
        
        // Lookup in scope
        return scope_.lookup(name);
    }
    
    /// Evaluate array
    private Result!(Value, BuildError) evaluateArray(ExpressionValue[] elements) @system
    {
        Value[] result;
        result.reserve(elements.length);
        
        foreach (elem; elements)
        {
            auto evalResult = evaluate(elem);
            if (evalResult.isErr)
                return evalResult;
            result ~= evalResult.unwrap();
        }
        
        return Result!(Value, BuildError).ok(Value.makeArray(result));
    }
    
    /// Evaluate map
    private Result!(Value, BuildError) evaluateMap(ExpressionValue[string] map) @system
    {
        Value[string] result;
        
        foreach (key, value; map)
        {
            auto evalResult = evaluate(value);
            if (evalResult.isErr)
                return Result!(Value, BuildError).err(evalResult.unwrapErr());
            result[key] = evalResult.unwrap();
        }
        
        return Result!(Value, BuildError).ok(Value.makeMap(result));
    }
    
    /// Evaluate binary operation
    Result!(Value, BuildError) evaluateBinary(string op, Value left, Value right) @system
    {
        switch (op)
        {
            // Arithmetic
            case "+":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeNumber(left.asNumber() + right.asNumber()));
                else if (left.isString() && right.isString())
                    return ok(Value.makeString(left.asString() ~ right.asString()));
                else if (left.isArray() && right.isArray())
                    return ok(Value.makeArray(left.asArray() ~ right.asArray()));
                else
                    return err("Cannot add " ~ left.type().to!string ~ " and " ~ right.type().to!string);
            
            case "-":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeNumber(left.asNumber() - right.asNumber()));
                else
                    return err("Cannot subtract non-numbers");
            
            case "*":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeNumber(left.asNumber() * right.asNumber()));
                else
                    return err("Cannot multiply non-numbers");
            
            case "/":
                if (left.isNumber() && right.isNumber())
                {
                    if (right.asNumber() == 0.0)
                        return err("Division by zero");
                    return ok(Value.makeNumber(left.asNumber() / right.asNumber()));
                }
                else
                    return err("Cannot divide non-numbers");
            
            case "%":
                if (left.isNumber() && right.isNumber())
                {
                    if (right.asNumber() == 0.0)
                        return err("Modulo by zero");
                    return ok(Value.makeNumber(left.asNumber() % right.asNumber()));
                }
                else
                    return err("Cannot modulo non-numbers");
            
            // Comparison
            case "==":
                return ok(Value.makeBool(left == right));
            
            case "!=":
                return ok(Value.makeBool(left != right));
            
            case "<":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeBool(left.asNumber() < right.asNumber()));
                else if (left.isString() && right.isString())
                    return ok(Value.makeBool(left.asString() < right.asString()));
                else
                    return err("Cannot compare non-comparable types");
            
            case "<=":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeBool(left.asNumber() <= right.asNumber()));
                else if (left.isString() && right.isString())
                    return ok(Value.makeBool(left.asString() <= right.asString()));
                else
                    return err("Cannot compare non-comparable types");
            
            case ">":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeBool(left.asNumber() > right.asNumber()));
                else if (left.isString() && right.isString())
                    return ok(Value.makeBool(left.asString() > right.asString()));
                else
                    return err("Cannot compare non-comparable types");
            
            case ">=":
                if (left.isNumber() && right.isNumber())
                    return ok(Value.makeBool(left.asNumber() >= right.asNumber()));
                else if (left.isString() && right.isString())
                    return ok(Value.makeBool(left.asString() >= right.asString()));
                else
                    return err("Cannot compare non-comparable types");
            
            // Logical
            case "&&":
                return ok(Value.makeBool(left.toBool() && right.toBool()));
            
            case "||":
                return ok(Value.makeBool(left.toBool() || right.toBool()));
            
            default:
                return err("Unknown binary operator: " ~ op);
        }
    }
    
    /// Evaluate unary operation
    Result!(Value, BuildError) evaluateUnary(string op, Value operand) @system
    {
        switch (op)
        {
            case "-":
                if (operand.isNumber())
                    return ok(Value.makeNumber(-operand.asNumber()));
                else
                    return err("Cannot negate non-number");
            
            case "!":
                return ok(Value.makeBool(!operand.toBool()));
            
            default:
                return err("Unknown unary operator: " ~ op);
        }
    }
    
    /// Evaluate function call
    Result!(Value, BuildError) evaluateCall(string name, Value[] args) @system
    {
        // Check if it's a built-in function
        if (builtins.has(name))
        {
            auto fnResult = builtins.get(name);
            if (fnResult.isErr)
                return Result!(Value, BuildError).err(fnResult.unwrapErr());
            
            auto fn = fnResult.unwrap();
            return fn(args);
        }
        
        // Check if it's a user-defined function
        auto lookupResult = scope_.lookup(name);
        if (lookupResult.isErr)
        {
            auto error = new ParseError("Undefined function '" ~ name ~ "'", null);
            error.addSuggestion("Define function with 'fn " ~ name ~ "(...) { ... }'");
            error.addSuggestion("Or use a built-in function: " ~ builtins.functionNames().join(", "));
            return Result!(Value, BuildError).err(error);
        }
        
        // User-defined functions not yet implemented in MVP
        return err("User-defined function calls not yet implemented");
    }
    
    /// Evaluate array indexing
    Result!(Value, BuildError) evaluateIndex(Value array, Value index) @system
    {
        if (!array.isArray())
            return err("Can only index arrays");
        
        if (!index.isNumber())
            return err("Array index must be a number");
        
        auto arr = array.asArray();
        auto idx = cast(size_t)index.asNumber();
        
        if (idx >= arr.length)
            return err("Array index " ~ idx.to!string ~ " out of bounds (length: " ~ arr.length.to!string ~ ")");
        
        return ok(arr[idx]);
    }
    
    /// Evaluate array slicing [start:end]
    Result!(Value, BuildError) evaluateSlice(Value array, Value start, Value end) @system
    {
        if (!array.isArray())
            return err("Can only slice arrays");
        
        auto arr = array.asArray();
        size_t startIdx = 0;
        size_t endIdx = arr.length;
        
        if (!start.isNull())
        {
            if (!start.isNumber())
                return err("Slice start must be a number");
            startIdx = cast(size_t)start.asNumber();
        }
        
        if (!end.isNull())
        {
            if (!end.isNumber())
                return err("Slice end must be a number");
            endIdx = cast(size_t)end.asNumber();
        }
        
        if (startIdx > endIdx || endIdx > arr.length)
            return err("Invalid slice range");
        
        return ok(Value.makeArray(arr[startIdx .. endIdx]));
    }
    
    /// Evaluate map access
    Result!(Value, BuildError) evaluateMapAccess(Value map, string key) @system
    {
        if (!map.isMap())
            return err("Can only access maps with []");
        
        auto m = map.asMap();
        if (key !in m)
            return err("Map key '" ~ key ~ "' not found");
        
        return ok(m[key]);
    }
    
    /// Evaluate ternary operator: condition ? trueExpr : falseExpr
    Result!(Value, BuildError) evaluateTernary(Value condition, Value trueVal, Value falseVal) @system
    {
        if (condition.toBool())
            return ok(trueVal);
        else
            return ok(falseVal);
    }
    
    /// Define variable (let or const)
    Result!BuildError defineVariable(string name, Value value, bool isConst) @system
    {
        return scope_.define(name, value, isConst);
    }
    
    /// Assign to variable
    Result!BuildError assignVariable(string name, Value value) @system
    {
        return scope_.assign(name, value);
    }
    
    /// Enter new scope
    void enterScope() pure nothrow @safe
    {
        scope_.enterScope();
    }
    
    /// Exit scope
    void exitScope() @trusted
    {
        scope_.exitScope();
    }
    
    /// Get type information for expression (without evaluation)
    Result!(ScriptTypeInfo, BuildError) inferType(ExpressionValue expr) @system
    {
        final switch (expr.type)
        {
            case ExpressionType.String:
                return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(ValueType.String));
            
            case ExpressionType.Number:
                return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(ValueType.Number));
            
            case ExpressionType.Identifier:
                auto name = expr.identifierValue;
                if (name == "true" || name == "false")
                    return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(ValueType.Bool));
                if (name == "null")
                    return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(ValueType.Null));
                
                // Lookup type from scope
                auto lookupResult = scope_.lookup(name);
                if (lookupResult.isErr)
                    return Result!(ScriptTypeInfo, BuildError).err(lookupResult.unwrapErr());
                
                auto value = lookupResult.unwrap();
                return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(value.type()));
            
            case ExpressionType.Array:
                // Infer element type from first element
                if (expr.arrayValue.empty)
                    return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.array(ValueType.Null));
                
                auto firstType = inferType(expr.arrayValue[0]);
                if (firstType.isErr)
                    return firstType;
                
                return Result!(ScriptTypeInfo, BuildError).ok(
                    ScriptTypeInfo.array(firstType.unwrap().valueType)
                );
            
            case ExpressionType.Map:
                // Maps are dynamically typed
                return Result!(ScriptTypeInfo, BuildError).ok(ScriptTypeInfo.simple(ValueType.Map));
        }
    }
    
    // Helper methods
    
    private Result!(Value, BuildError) ok(Value v) @system
    {
        return Result!(Value, BuildError).ok(v);
    }
    
    private Result!(Value, BuildError) err(string msg) @system
    {
        auto error = new ParseError(msg, null);
        return Result!(Value, BuildError).err(error);
    }
}

