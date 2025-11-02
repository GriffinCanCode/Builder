#!/usr/bin/env builder
// Example: Tier 2 - D-Based Macros
// Demonstrates full D language power for complex build logic

module builderfile;

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.conv;
import builder.macros;

/// Generate microservice targets with full configuration
Target[] generateMicroservices()
{
    struct ServiceSpec
    {
        string name;
        int port;
        string database;
        string[] dependencies;
        string[string] config;
    }
    
    // Complex configuration that would be tedious in Tier 1
    ServiceSpec[] services = [
        ServiceSpec("auth", 8001, "postgres", [], [
            "jwt_secret": "secret123",
            "token_expiry": "3600"
        ]),
        ServiceSpec("users", 8002, "postgres", ["auth"], [
            "max_connections": "100"
        ]),
        ServiceSpec("posts", 8003, "mongodb", ["auth", "users"], [
            "cache_enabled": "true",
            "cache_ttl": "300"
        ]),
        ServiceSpec("media", 8004, "s3", ["auth"], [
            "bucket": "media-uploads",
            "region": "us-east-1"
        ])
    ];
    
    return services.map!(svc =>
        TargetBuilder.create(svc.name)
            .type(TargetType.Executable)
            .language("go")
            .sources(["services/" ~ svc.name ~ "/**/*.go"])
            .deps(svc.dependencies.map!(d => ":" ~ d).array)
            .env([
                "PORT": svc.port.to!string,
                "SERVICE": svc.name,
                "DATABASE": svc.database
            ] ~ svc.config)
            .output("bin/" ~ svc.name ~ "-service")
            .build()
    ).array;
}

/// Generate platform-specific builds with optimization
Target[] generatePlatformBuilds()
{
    struct Platform
    {
        string os;
        string arch;
        string[] flags;
    }
    
    Platform[] platforms = [
        Platform("linux", "amd64", ["-ldflags", "-s -w", "-tags", "netgo"]),
        Platform("linux", "arm64", ["-ldflags", "-s -w", "-tags", "netgo"]),
        Platform("darwin", "amd64", ["-ldflags", "-s -w"]),
        Platform("darwin", "arm64", ["-ldflags", "-s -w"]),
        Platform("windows", "amd64", ["-ldflags", "-s -w", "-H", "windowsgui"])
    ];
    
    string appName = "myapp";
    string[] sources = ["cmd/main.go"];
    
    return platforms.map!(p =>
        TargetBuilder.create(appName ~ "-" ~ p.os ~ "-" ~ p.arch)
            .type(TargetType.Executable)
            .language("go")
            .sources(sources)
            .flags(p.flags)
            .env([
                "GOOS": p.os,
                "GOARCH": p.arch,
                "CGO_ENABLED": "0"
            ])
            .output("dist/" ~ appName ~ "-" ~ p.os ~ "-" ~ p.arch)
            .build()
    ).array;
}

/// Generate code from protobuf with multiple languages
Target[] generateProtobufTargets()
{
    import std.file : dirEntries, SpanMode;
    
    // Find all .proto files
    string[] protoFiles;
    foreach (entry; dirEntries("proto", "*.proto", SpanMode.depth))
        protoFiles ~= entry.name;
    
    // Languages to generate
    string[] languages = ["go", "python", "rust", "typescript"];
    
    Target[] targets;
    
    foreach (proto; protoFiles)
    {
        string baseName = proto.baseName.stripExtension;
        
        foreach (lang; languages)
        {
            string outputDir = "gen/" ~ lang;
            
            auto target = TargetBuilder.create(baseName ~ "-proto-" ~ lang)
                .type(TargetType.Custom)
                .sources([proto])
                .output(outputDir)
                .build();
            
            // Custom command for protobuf generation
            target.config["command"] = "protoc --" ~ lang ~ "_out=" ~ outputDir ~ " " ~ proto;
            target.config["plugin"] = "protobuf";
            
            targets ~= target;
        }
    }
    
    return targets;
}

/// Generate dependency graph programmatically
Target[] generateDependencyGraph()
{
    struct Layer
    {
        string name;
        string[] packages;
    }
    
    // Define architecture layers
    Layer[] layers = [
        Layer("foundation", ["logging", "config", "errors"]),
        Layer("data", ["database", "cache", "queue"]),
        Layer("domain", ["models", "validation", "business"]),
        Layer("application", ["services", "workflows", "events"]),
        Layer("presentation", ["api", "cli", "web"])
    ];
    
    Target[] targets;
    string[] previousDeps;
    
    foreach (layer; layers)
    {
        foreach (pkg; layer.packages)
        {
            auto target = TargetBuilder.create(pkg)
                .type(TargetType.Library)
                .language("d")
                .sources(["src/" ~ layer.name ~ "/" ~ pkg ~ "/**/*.d"])
                .deps(previousDeps.dup)
                .build();
            
            targets ~= target;
        }
        
        // Next layer depends on this layer
        previousDeps = layer.packages.map!(p => ":" ~ p).array;
    }
    
    // Main app depends on presentation layer
    targets ~= TargetBuilder.create("app")
        .type(TargetType.Executable)
        .language("d")
        .sources(["src/main.d"])
        .deps(previousDeps)
        .output("bin/app")
        .build();
    
    return targets;
}

/// Advanced: Generate targets based on file structure
Target[] inferTargetsFromStructure()
{
    Target[] targets;
    
    // Scan for package.json files (Node.js projects)
    foreach (entry; dirEntries("packages", SpanMode.depth))
    {
        if (entry.name.baseName == "package.json")
        {
            string pkgDir = entry.name.dirName;
            string pkgName = pkgDir.baseName;
            
            targets ~= TargetBuilder.create(pkgName)
                .type(TargetType.Library)
                .language("javascript")
                .sources([pkgDir ~ "/**/*.js"])
                .output("dist/" ~ pkgName ~ ".js")
                .build();
        }
    }
    
    return targets;
}

/// Main entry point
void main()
{
    import std.stdio;
    import std.json;
    
    // Collect all generated targets
    Target[] allTargets;
    allTargets ~= generateMicroservices();
    allTargets ~= generatePlatformBuilds();
    allTargets ~= generateProtobufTargets();
    allTargets ~= generateDependencyGraph();
    allTargets ~= inferTargetsFromStructure();
    
    // Output as JSON for Builder to parse
    JSONValue[] targetJson;
    foreach (target; allTargets)
    {
        JSONValue t;
        t["name"] = target.name;
        t["type"] = target.type.to!string;
        t["language"] = target.language;
        t["sources"] = JSONValue(target.sources);
        t["deps"] = JSONValue(target.deps);
        if (target.output.length > 0)
            t["output"] = target.output;
        targetJson ~= t;
    }
    
    writeln(JSONValue(targetJson).toPrettyString);
}

// Register macros for use in Builderfile DSL
mixin RegisterMacro!(generateMicroservices, "generateMicroservices");
mixin RegisterMacro!(generatePlatformBuilds, "generatePlatformBuilds");
mixin RegisterMacro!(generateProtobufTargets, "generateProtobufTargets");

