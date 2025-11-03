module infrastructure.migration.systems.cargo;

import std.json;
import std.string;
import std.array;
import std.algorithm;
import std.file : readText;
import infrastructure.migration.base;
import infrastructure.migration.common;
import infrastructure.config.schema.schema : TargetType, TargetLanguage;
import infrastructure.errors;

/// Migrator for Rust Cargo.toml files
final class CargoMigrator : BaseMigrator
{
    override string systemName() const pure nothrow @safe { return "cargo"; }
    
    override string[] defaultFileNames() const pure nothrow @safe
    {
        return ["Cargo.toml"];
    }
    
    override bool canMigrate(string filePath) const @safe
    {
        import std.path : baseName;
        return baseName(filePath) == "Cargo.toml";
    }
    
    override string description() const pure nothrow @safe
    {
        return "Migrates Rust Cargo.toml to Builderfile format";
    }
    
    override string[] supportedFeatures() const pure nothrow @safe
    {
        return [
            "Binary targets [[bin]]",
            "Library targets [lib]",
            "Test targets",
            "Dependencies",
            "Dev dependencies",
            "Build dependencies"
        ];
    }
    
    override string[] limitations() const pure nothrow @safe
    {
        return [
            "Cargo features require manual configuration",
            "Build scripts (build.rs) need manual review",
            "Workspace members need separate migration"
        ];
    }
    
    override Result!(MigrationResult, BuildError) migrate(string inputPath) @system
    {
        auto contentResult = readInputFile(inputPath);
        if (contentResult.isErr)
            return Result!(MigrationResult, BuildError).err(contentResult.unwrapErr());
        
        auto content = contentResult.unwrap();
        MigrationTarget[] targets;
        MigrationWarning[] warnings;
        
        try
        {
            // Parse TOML using simple pattern matching (full TOML parser would be better)
            
            // Check for [lib] section
            if (content.indexOf("[lib]") >= 0)
            {
                MigrationTarget target;
                target.name = extractPackageName(content) ~ "-lib";
                target.type = TargetType.Library;
                target.language = TargetLanguage.Rust;
                target.sources = ["src/lib.rs"];
                targets ~= target;
            }
            
            // Check for [[bin]] sections or default src/main.rs
            if (content.indexOf("[[bin]]") >= 0 || content.indexOf("src/main.rs") >= 0)
            {
                MigrationTarget target;
                target.name = extractPackageName(content);
                target.type = TargetType.Executable;
                target.language = TargetLanguage.Rust;
                target.sources = ["src/main.rs"];
                
                // Parse dependencies
                target.dependencies = parseCargoDependencies(content);
                
                targets ~= target;
            }
            
            // Add info about dev-dependencies
            auto devDeps = parseCargoSection(content, "[dev-dependencies]");
            if (devDeps.length > 0)
            {
                warnings ~= MigrationWarning(WarningLevel.Info,
                    "Dev dependencies found: " ~ devDeps.join(", "),
                    "Add these to test target dependencies if needed");
            }
        }
        catch (Exception e)
        {
            return Result!(MigrationResult, BuildError).err(
                migrationError("Failed to parse Cargo.toml: " ~ e.msg, inputPath));
        }
        
        if (targets.length == 0)
        {
            // Create default binary target
            MigrationTarget target;
            target.name = "app";
            target.type = TargetType.Executable;
            target.language = TargetLanguage.Rust;
            target.sources = ["src/main.rs"];
            targets ~= target;
            
            warnings ~= MigrationWarning(WarningLevel.Info,
                "Created default binary target", "Review and adjust as needed");
        }
        
        MigrationResult result;
        result.targets = targets;
        result.warnings = warnings;
        result.success = true;
        
        return Result!(MigrationResult, BuildError).ok(result);
    }
    
    private string extractPackageName(string content)
    {
        import std.regex;
        auto pattern = regex(`name\s*=\s*"([^"]+)"`);
        auto match = matchFirst(content, pattern);
        return match.empty ? "app" : match[1];
    }
    
    private string[] parseCargoDependencies(string content)
    {
        return parseCargoSection(content, "[dependencies]");
    }
    
    private string[] parseCargoSection(string content, string section)
    {
        auto idx = content.indexOf(section);
        if (idx < 0)
            return [];
        
        // Find next section or end
        auto remaining = content[idx + section.length .. $];
        auto nextSection = remaining.indexOf("\n[");
        if (nextSection >= 0)
            remaining = remaining[0 .. nextSection];
        
        // Extract dependency names (simple line-by-line parsing)
        import std.regex;
        auto pattern = regex(`^(\w+)\s*=`, "m");
        string[] deps;
        
        foreach (match; matchAll(remaining, pattern))
        {
            deps ~= match[1];
        }
        
        return deps;
    }
}

