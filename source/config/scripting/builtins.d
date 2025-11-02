module config.scripting.builtins;

import std.string;
import std.algorithm;
import std.array;
import std.conv;
import std.path;
import std.file;
import std.process : environment;
import std.range;
import config.scripting.types;
import utils.files.glob;
import errors;

/// Built-in function registry
class BuiltinRegistry
{
    private BuiltinFunction[string] functions;
    private FunctionSignature[string] signatures;
    
    this() @system
    {
        registerStandardLibrary();
    }
    
    /// Register standard library functions
    private void registerStandardLibrary() @system
    {
        // String operations
        register("upper", &builtinUpper, ["str"], [ValueType.String], ValueType.String);
        register("lower", &builtinLower, ["str"], [ValueType.String], ValueType.String);
        register("trim", &builtinTrim, ["str"], [ValueType.String], ValueType.String);
        register("split", &builtinSplit, ["str", "sep"], [ValueType.String, ValueType.String], ValueType.Array);
        register("join", &builtinJoin, ["arr", "sep"], [ValueType.Array, ValueType.String], ValueType.String);
        register("replace", &builtinReplace, ["str", "old", "new"], 
                 [ValueType.String, ValueType.String, ValueType.String], ValueType.String);
        register("startsWith", &builtinStartsWith, ["str", "prefix"], 
                 [ValueType.String, ValueType.String], ValueType.Bool);
        register("endsWith", &builtinEndsWith, ["str", "suffix"], 
                 [ValueType.String, ValueType.String], ValueType.Bool);
        register("contains", &builtinContains, ["str", "substr"], 
                 [ValueType.String, ValueType.String], ValueType.Bool);
        
        // Array operations
        register("len", &builtinLen, ["collection"], [ValueType.Array], ValueType.Number);
        register("append", &builtinAppend, ["arr", "elem"], [ValueType.Array, ValueType.Null], ValueType.Array);
        register("filter", &builtinFilter, ["arr", "fn"], [ValueType.Array, ValueType.Function], ValueType.Array);
        register("map", &builtinMap, ["arr", "fn"], [ValueType.Array, ValueType.Function], ValueType.Array);
        register("range", &builtinRange, ["start", "end"], [ValueType.Number, ValueType.Number], ValueType.Array);
        
        // Type conversions
        register("str", &builtinStr, ["value"], [ValueType.Null], ValueType.String);
        register("int", &builtinInt, ["value"], [ValueType.Null], ValueType.Number);
        register("bool", &builtinBool, ["value"], [ValueType.Null], ValueType.Bool);
        
        // File operations
        register("glob", &builtinGlob, ["pattern"], [ValueType.String], ValueType.Array);
        register("fileExists", &builtinFileExists, ["path"], [ValueType.String], ValueType.Bool);
        register("readFile", &builtinReadFile, ["path"], [ValueType.String], ValueType.String);
        register("basename", &builtinBasename, ["path"], [ValueType.String], ValueType.String);
        register("dirname", &builtinDirname, ["path"], [ValueType.String], ValueType.String);
        register("stripExtension", &builtinStripExtension, ["path"], [ValueType.String], ValueType.String);
        
        // Environment
        register("env", &builtinEnv, ["name", "default"], 
                 [ValueType.String, ValueType.String], ValueType.String);
        register("platform", &builtinPlatform, [], [], ValueType.String);
        register("arch", &builtinArch, [], [], ValueType.String);
    }
    
    /// Register function
    private void register(
        string name,
        BuiltinFunction fn,
        string[] paramNames,
        ValueType[] paramTypes,
        ValueType returnType
    ) @system
    {
        functions[name] = fn;
        
        FunctionSignature sig;
        sig.name = name;
        sig.paramNames = paramNames;
        sig.paramTypes = paramTypes;
        sig.returnType = returnType;
        sig.isVariadic = false;
        signatures[name] = sig;
    }
    
    /// Check if function exists
    bool has(string name) const pure nothrow @trusted
    {
        return (name in functions) !is null;
    }
    
    /// Get function
    Result!(BuiltinFunction, BuildError) get(string name) @trusted
    {
        if (name !in functions)
        {
            auto error = new ParseError("Undefined function '" ~ name ~ "'", null);
            error.addSuggestion("Check function name spelling");
            error.addSuggestion("Use one of the built-in functions: " ~ 
                                functions.keys.join(", "));
            return Result!(BuiltinFunction, BuildError).err(error);
        }
        return Result!(BuiltinFunction, BuildError).ok(functions[name]);
    }
    
    /// Get signature
    Result!(FunctionSignature, BuildError) getSignature(string name) @trusted
    {
        if (name !in signatures)
        {
            auto error = new ParseError("Undefined function '" ~ name ~ "'", null);
            return Result!(FunctionSignature, BuildError).err(error);
        }
        return Result!(FunctionSignature, BuildError).ok(signatures[name]);
    }
    
    /// List all function names
    string[] functionNames() const @trusted
    {
        return functions.keys;
    }
}

// String operations

private Result!(Value, BuildError) builtinUpper(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("upper() expects 1 string argument");
    return ok(Value.makeString(args[0].asString().toUpper()));
}

private Result!(Value, BuildError) builtinLower(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("lower() expects 1 string argument");
    return ok(Value.makeString(args[0].asString().toLower()));
}

private Result!(Value, BuildError) builtinTrim(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("trim() expects 1 string argument");
    return ok(Value.makeString(args[0].asString().strip()));
}

private Result!(Value, BuildError) builtinSplit(Value[] args) @system
{
    if (args.length != 2 || !args[0].isString() || !args[1].isString())
        return err("split() expects 2 string arguments");
    
    auto parts = args[0].asString().split(args[1].asString());
    auto result = parts.map!(p => Value.makeString(p)).array;
    return ok(Value.makeArray(result));
}

private Result!(Value, BuildError) builtinJoin(Value[] args) @system
{
    if (args.length != 2 || !args[0].isArray() || !args[1].isString())
        return err("join() expects array and string arguments");
    
    auto arr = args[0].asArray();
    auto sep = args[1].asString();
    auto strings = arr.map!(v => v.toString()).array;
    return ok(Value.makeString(strings.join(sep)));
}

private Result!(Value, BuildError) builtinReplace(Value[] args) @system
{
    if (args.length != 3 || !args[0].isString() || !args[1].isString() || !args[2].isString())
        return err("replace() expects 3 string arguments");
    
    auto result = args[0].asString().replace(args[1].asString(), args[2].asString());
    return ok(Value.makeString(result));
}

private Result!(Value, BuildError) builtinStartsWith(Value[] args) @system
{
    if (args.length != 2 || !args[0].isString() || !args[1].isString())
        return err("startsWith() expects 2 string arguments");
    
    auto result = args[0].asString().startsWith(args[1].asString());
    return ok(Value.makeBool(result));
}

private Result!(Value, BuildError) builtinEndsWith(Value[] args) @system
{
    if (args.length != 2 || !args[0].isString() || !args[1].isString())
        return err("endsWith() expects 2 string arguments");
    
    auto result = args[0].asString().endsWith(args[1].asString());
    return ok(Value.makeBool(result));
}

private Result!(Value, BuildError) builtinContains(Value[] args) @system
{
    if (args.length != 2 || !args[0].isString() || !args[1].isString())
        return err("contains() expects 2 string arguments");
    
    auto result = args[0].asString().canFind(args[1].asString());
    return ok(Value.makeBool(result));
}

// Array operations

private Result!(Value, BuildError) builtinLen(Value[] args) @system
{
    if (args.length != 1)
        return err("len() expects 1 argument");
    
    if (args[0].isArray())
        return ok(Value.makeNumber(args[0].asArray().length));
    else if (args[0].isString())
        return ok(Value.makeNumber(args[0].asString().length));
    else if (args[0].isMap())
        return ok(Value.makeNumber(args[0].asMap().length));
    else
        return err("len() expects array, string, or map");
}

private Result!(Value, BuildError) builtinAppend(Value[] args) @system
{
    if (args.length != 2 || !args[0].isArray())
        return err("append() expects array and element");
    
    auto arr = args[0].asArray().dup;
    arr ~= args[1];
    return ok(Value.makeArray(arr));
}

private Result!(Value, BuildError) builtinFilter(Value[] args) @system
{
    // Note: This is a placeholder. Full implementation requires function calling
    return err("filter() not yet implemented - requires function evaluation");
}

private Result!(Value, BuildError) builtinMap(Value[] args) @system
{
    // Note: This is a placeholder. Full implementation requires function calling
    return err("map() not yet implemented - requires function evaluation");
}

private Result!(Value, BuildError) builtinRange(Value[] args) @system
{
    if (args.length != 2 || !args[0].isNumber() || !args[1].isNumber())
        return err("range() expects 2 number arguments");
    
    auto start = cast(int)args[0].asNumber();
    auto end = cast(int)args[1].asNumber();
    
    Value[] result;
    foreach (i; start .. end)
        result ~= Value.makeNumber(i);
    
    return ok(Value.makeArray(result));
}

// Type conversions

private Result!(Value, BuildError) builtinStr(Value[] args) @system
{
    if (args.length != 1)
        return err("str() expects 1 argument");
    return ok(Value.makeString(args[0].toString()));
}

private Result!(Value, BuildError) builtinInt(Value[] args) @system
{
    if (args.length != 1)
        return err("int() expects 1 argument");
    
    if (args[0].isNumber())
        return ok(Value.makeNumber(cast(int)args[0].asNumber()));
    else if (args[0].isString())
    {
        try
        {
            auto num = args[0].asString().to!int;
            return ok(Value.makeNumber(num));
        }
        catch (Exception e)
        {
            return err("Cannot convert '" ~ args[0].asString() ~ "' to int");
        }
    }
    else
        return err("int() expects number or string");
}

private Result!(Value, BuildError) builtinBool(Value[] args) @system
{
    if (args.length != 1)
        return err("bool() expects 1 argument");
    return ok(Value.makeBool(args[0].toBool()));
}

// File operations

private Result!(Value, BuildError) builtinGlob(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("glob() expects 1 string argument");
    
    try
    {
        auto pattern = args[0].asString();
        auto files = expandGlob(pattern);
        auto result = files.map!(f => Value.makeString(f)).array;
        return ok(Value.makeArray(result));
    }
    catch (Exception e)
    {
        return err("glob() failed: " ~ e.msg);
    }
}

private Result!(Value, BuildError) builtinFileExists(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("fileExists() expects 1 string argument");
    
    auto path = args[0].asString();
    auto exists = std.file.exists(path);
    return ok(Value.makeBool(exists));
}

private Result!(Value, BuildError) builtinReadFile(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("readFile() expects 1 string argument");
    
    try
    {
        auto path = args[0].asString();
        auto content = std.file.readText(path);
        return ok(Value.makeString(content));
    }
    catch (Exception e)
    {
        return err("readFile() failed: " ~ e.msg);
    }
}

private Result!(Value, BuildError) builtinBasename(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("basename() expects 1 string argument");
    
    auto result = baseName(args[0].asString());
    return ok(Value.makeString(result));
}

private Result!(Value, BuildError) builtinDirname(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("dirname() expects 1 string argument");
    
    auto result = dirName(args[0].asString());
    return ok(Value.makeString(result));
}

private Result!(Value, BuildError) builtinStripExtension(Value[] args) @system
{
    if (args.length != 1 || !args[0].isString())
        return err("stripExtension() expects 1 string argument");
    
    auto result = stripExtension(args[0].asString());
    return ok(Value.makeString(result));
}

// Environment

private Result!(Value, BuildError) builtinEnv(Value[] args) @system
{
    if (args.length < 1 || args.length > 2 || !args[0].isString())
        return err("env() expects 1-2 arguments (name, default)");
    
    auto name = args[0].asString();
    auto value = environment.get(name, null);
    
    if (value is null)
    {
        if (args.length == 2 && args[1].isString())
            value = args[1].asString();
        else
            value = "";
    }
    
    return ok(Value.makeString(value));
}

private Result!(Value, BuildError) builtinPlatform(Value[] args) @system
{
    if (args.length != 0)
        return err("platform() expects no arguments");
    
    version (linux)
        return ok(Value.makeString("linux"));
    else version (OSX)
        return ok(Value.makeString("darwin"));
    else version (Windows)
        return ok(Value.makeString("windows"));
    else
        return ok(Value.makeString("unknown"));
}

private Result!(Value, BuildError) builtinArch(Value[] args) @system
{
    if (args.length != 0)
        return err("arch() expects no arguments");
    
    version (X86_64)
        return ok(Value.makeString("x86_64"));
    else version (AArch64)
        return ok(Value.makeString("arm64"));
    else version (ARM)
        return ok(Value.makeString("arm"));
    else
        return ok(Value.makeString("unknown"));
}

// Helpers

private Result!(Value, BuildError) ok(Value v) @system
{
    return Result!(Value, BuildError).ok(v);
}

private Result!(Value, BuildError) err(string msg) @system
{
    auto error = new ParseError(msg, null);
    return Result!(Value, BuildError).err(error);
}

