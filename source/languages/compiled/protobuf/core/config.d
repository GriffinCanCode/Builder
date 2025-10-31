module languages.compiled.protobuf.core.config;

import std.json;
import std.conv;
import std.algorithm;
import std.uni : toLower;

/// Protocol Buffer compiler type
enum ProtocCompiler
{
    Auto,      // Auto-detect best available
    Protoc,    // Standard Google protoc
    Buf        // Buf CLI (modern alternative)
}

/// Output language for protobuf compilation
enum ProtobufOutputLanguage
{
    Cpp,
    CSharp,
    Java,
    Kotlin,
    ObjectiveC,
    PHP,
    Python,
    Ruby,
    Go,
    Rust,
    JavaScript,
    TypeScript,
    Dart,
    Swift
}

/// Protobuf configuration
struct ProtobufConfig
{
    ProtocCompiler compiler = ProtocCompiler.Auto;
    ProtobufOutputLanguage outputLanguage = ProtobufOutputLanguage.Cpp;
    
    string outputDir;           // Output directory for generated code
    string[] importPaths;       // Additional import paths
    string[] plugins;           // Protoc plugins to use
    
    bool generateDescriptor;    // Generate descriptor set
    string descriptorPath;      // Path for descriptor output
    
    bool lint;                  // Run linting
    bool format;                // Format proto files
    
    // Plugin-specific options
    string[string] pluginOptions; // Key-value options for plugins
    
    /// Parse from JSON
    static ProtobufConfig fromJSON(JSONValue json)
    {
        ProtobufConfig config;
        
        if ("compiler" in json)
        {
            string compilerStr = json["compiler"].str.toLower;
            switch (compilerStr)
            {
                case "auto": config.compiler = ProtocCompiler.Auto; break;
                case "protoc": config.compiler = ProtocCompiler.Protoc; break;
                case "buf": config.compiler = ProtocCompiler.Buf; break;
                default: break;
            }
        }
        
        if ("outputLanguage" in json)
        {
            string langStr = json["outputLanguage"].str.toLower;
            switch (langStr)
            {
                case "cpp", "c++": config.outputLanguage = ProtobufOutputLanguage.Cpp; break;
                case "csharp", "cs": config.outputLanguage = ProtobufOutputLanguage.CSharp; break;
                case "java": config.outputLanguage = ProtobufOutputLanguage.Java; break;
                case "kotlin": config.outputLanguage = ProtobufOutputLanguage.Kotlin; break;
                case "objc", "objective-c": config.outputLanguage = ProtobufOutputLanguage.ObjectiveC; break;
                case "php": config.outputLanguage = ProtobufOutputLanguage.PHP; break;
                case "python", "py": config.outputLanguage = ProtobufOutputLanguage.Python; break;
                case "ruby", "rb": config.outputLanguage = ProtobufOutputLanguage.Ruby; break;
                case "go": config.outputLanguage = ProtobufOutputLanguage.Go; break;
                case "rust": config.outputLanguage = ProtobufOutputLanguage.Rust; break;
                case "javascript", "js": config.outputLanguage = ProtobufOutputLanguage.JavaScript; break;
                case "typescript", "ts": config.outputLanguage = ProtobufOutputLanguage.TypeScript; break;
                case "dart": config.outputLanguage = ProtobufOutputLanguage.Dart; break;
                case "swift": config.outputLanguage = ProtobufOutputLanguage.Swift; break;
                default: break;
            }
        }
        
        if ("outputDir" in json)
            config.outputDir = json["outputDir"].str;
        
        if ("importPaths" in json && json["importPaths"].type == JSONType.array)
        {
            foreach (path; json["importPaths"].array)
                config.importPaths ~= path.str;
        }
        
        if ("plugins" in json && json["plugins"].type == JSONType.array)
        {
            foreach (plugin; json["plugins"].array)
                config.plugins ~= plugin.str;
        }
        
        if ("generateDescriptor" in json)
            config.generateDescriptor = json["generateDescriptor"].type == JSONType.true_;
        
        if ("descriptorPath" in json)
            config.descriptorPath = json["descriptorPath"].str;
        
        if ("lint" in json)
            config.lint = json["lint"].type == JSONType.true_;
        
        if ("format" in json)
            config.format = json["format"].type == JSONType.true_;
        
        if ("pluginOptions" in json && json["pluginOptions"].type == JSONType.object)
        {
            foreach (key, value; json["pluginOptions"].object)
                config.pluginOptions[key] = value.str;
        }
        
        return config;
    }
}

