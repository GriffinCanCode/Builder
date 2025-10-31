module languages.compiled.protobuf.tooling.protoc;

import std.process;
import std.string;
import std.path;
import std.array;
import std.algorithm;
import std.file;
import languages.compiled.protobuf.core.config;
import utils.logging.logger;

/// Result of protoc compilation
struct ProtocResult
{
    bool success;
    string error;
    string[] outputs;
    string[] warnings;
}

/// Protocol Buffer compiler wrapper
class ProtocWrapper
{
    /// Check if protoc is available
    static bool isAvailable()
    {
        try
        {
            auto result = execute(["protoc", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get protoc version
    static string getVersion()
    {
        try
        {
            auto result = execute(["protoc", "--version"]);
            if (result.status == 0)
                return result.output.strip;
            return "unknown";
        }
        catch (Exception e)
        {
            return "unknown";
        }
    }
    
    /// Compile proto files
    static ProtocResult compile(
        const string[] protoFiles,
        const ProtobufConfig config,
        const string workspaceRoot
    )
    {
        ProtocResult result;
        
        if (!isAvailable())
        {
            result.error = "protoc compiler not found. Install from: https://protobuf.dev/downloads/";
            return result;
        }
        
        // Build protoc command
        string[] cmd = ["protoc"];
        
        // Add import paths
        foreach (importPath; config.importPaths)
        {
            cmd ~= "-I" ~ importPath;
        }
        
        // Add workspace root as import path
        if (!workspaceRoot.empty)
        {
            cmd ~= "-I" ~ workspaceRoot;
        }
        
        // Add output directory and language
        string outputFlag = getOutputFlag(config.outputLanguage);
        string outputDir = config.outputDir.empty ? "." : config.outputDir;
        cmd ~= outputFlag ~ "=" ~ outputDir;
        
        // Add plugins
        foreach (plugin; config.plugins)
        {
            cmd ~= "--plugin=" ~ plugin;
        }
        
        // Add plugin options
        foreach (key, value; config.pluginOptions)
        {
            cmd ~= "--" ~ key ~ "=" ~ value;
        }
        
        // Generate descriptor if requested
        if (config.generateDescriptor)
        {
            string descPath = config.descriptorPath.empty ? 
                             buildPath(outputDir, "descriptor.pb") : 
                             config.descriptorPath;
            cmd ~= "--descriptor_set_out=" ~ descPath;
            cmd ~= "--include_imports";
            cmd ~= "--include_source_info";
        }
        
        // Add proto files
        cmd ~= protoFiles.dup;
        
        Logger.debugLog("Running: " ~ cmd.join(" "));
        
        try
        {
            // Create output directory if it doesn't exist
            if (!outputDir.empty && !exists(outputDir))
            {
                mkdirRecurse(outputDir);
            }
            
            auto execResult = execute(cmd);
            
            if (execResult.status == 0)
            {
                result.success = true;
                
                // Collect generated files
                result.outputs = collectGeneratedFiles(outputDir, config.outputLanguage);
                
                // Parse warnings from output
                if (!execResult.output.empty)
                {
                    foreach (line; execResult.output.lineSplitter)
                    {
                        if (line.toLower.canFind("warning"))
                            result.warnings ~= line;
                    }
                }
            }
            else
            {
                result.error = execResult.output;
            }
        }
        catch (Exception e)
        {
            result.error = "Failed to execute protoc: " ~ e.msg;
        }
        
        return result;
    }
    
    /// Get output flag for language
    private static string getOutputFlag(ProtobufOutputLanguage lang)
    {
        final switch (lang)
        {
            case ProtobufOutputLanguage.Cpp: return "--cpp_out";
            case ProtobufOutputLanguage.CSharp: return "--csharp_out";
            case ProtobufOutputLanguage.Java: return "--java_out";
            case ProtobufOutputLanguage.Kotlin: return "--kotlin_out";
            case ProtobufOutputLanguage.ObjectiveC: return "--objc_out";
            case ProtobufOutputLanguage.PHP: return "--php_out";
            case ProtobufOutputLanguage.Python: return "--python_out";
            case ProtobufOutputLanguage.Ruby: return "--ruby_out";
            case ProtobufOutputLanguage.Go: return "--go_out";
            case ProtobufOutputLanguage.Rust: return "--rust_out";
            case ProtobufOutputLanguage.JavaScript: return "--js_out";
            case ProtobufOutputLanguage.TypeScript: return "--ts_out";
            case ProtobufOutputLanguage.Dart: return "--dart_out";
            case ProtobufOutputLanguage.Swift: return "--swift_out";
        }
    }
    
    /// Collect generated files based on output language
    private static string[] collectGeneratedFiles(string outputDir, ProtobufOutputLanguage lang)
    {
        string[] files;
        
        if (!exists(outputDir) || !isDir(outputDir))
            return files;
        
        string[] extensions = getOutputExtensions(lang);
        
        try
        {
            foreach (DirEntry entry; dirEntries(outputDir, SpanMode.depth))
            {
                if (entry.isFile)
                {
                    string ext = extension(entry.name);
                    if (extensions.canFind(ext))
                    {
                        files ~= entry.name;
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Error collecting generated files: " ~ e.msg);
        }
        
        return files;
    }
    
    /// Get file extensions for output language
    private static string[] getOutputExtensions(ProtobufOutputLanguage lang)
    {
        final switch (lang)
        {
            case ProtobufOutputLanguage.Cpp: return [".pb.cc", ".pb.h"];
            case ProtobufOutputLanguage.CSharp: return [".cs"];
            case ProtobufOutputLanguage.Java: return [".java"];
            case ProtobufOutputLanguage.Kotlin: return [".kt"];
            case ProtobufOutputLanguage.ObjectiveC: return [".pbobjc.h", ".pbobjc.m"];
            case ProtobufOutputLanguage.PHP: return [".php"];
            case ProtobufOutputLanguage.Python: return ["_pb2.py"];
            case ProtobufOutputLanguage.Ruby: return ["_pb.rb"];
            case ProtobufOutputLanguage.Go: return [".pb.go"];
            case ProtobufOutputLanguage.Rust: return [".rs"];
            case ProtobufOutputLanguage.JavaScript: return [".js"];
            case ProtobufOutputLanguage.TypeScript: return [".ts"];
            case ProtobufOutputLanguage.Dart: return [".pb.dart"];
            case ProtobufOutputLanguage.Swift: return [".pb.swift"];
        }
    }
}

/// Buf CLI wrapper (modern alternative to protoc)
class BufWrapper
{
    /// Check if buf is available
    static bool isAvailable()
    {
        try
        {
            auto result = execute(["buf", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get buf version
    static string getVersion()
    {
        try
        {
            auto result = execute(["buf", "--version"]);
            if (result.status == 0)
                return result.output.strip;
            return "unknown";
        }
        catch (Exception e)
        {
            return "unknown";
        }
    }
    
    /// Run buf lint
    static ProtocResult lint(const string[] protoFiles)
    {
        ProtocResult result;
        
        if (!isAvailable())
        {
            result.error = "buf not found";
            return result;
        }
        
        try
        {
            auto execResult = execute(["buf", "lint"] ~ protoFiles.dup);
            result.success = execResult.status == 0;
            
            if (!result.success)
            {
                result.error = execResult.output;
            }
            else if (!execResult.output.empty)
            {
                result.warnings ~= execResult.output.split("\n");
            }
        }
        catch (Exception e)
        {
            result.error = "Failed to run buf lint: " ~ e.msg;
        }
        
        return result;
    }
    
    /// Run buf format
    static ProtocResult format(const string[] protoFiles, bool writeInPlace = false)
    {
        ProtocResult result;
        
        if (!isAvailable())
        {
            result.error = "buf not found";
            return result;
        }
        
        try
        {
            string[] cmd = ["buf", "format"];
            if (writeInPlace)
                cmd ~= "-w";
            cmd ~= protoFiles.dup;
            
            auto execResult = execute(cmd);
            result.success = execResult.status == 0;
            
            if (!result.success)
            {
                result.error = execResult.output;
            }
        }
        catch (Exception e)
        {
            result.error = "Failed to run buf format: " ~ e.msg;
        }
        
        return result;
    }
}

