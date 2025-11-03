module migration.systems.npm;

import std.json;
import std.string;
import std.array;
import std.algorithm;
import migration.base;
import migration.common;
import config.schema.schema : TargetType, TargetLanguage;
import errors;

/// Migrator for npm package.json files
final class NpmMigrator : BaseMigrator
{
    override string systemName() const pure nothrow @safe { return "npm"; }
    
    override string[] defaultFileNames() const pure nothrow @safe
    {
        return ["package.json"];
    }
    
    override bool canMigrate(string filePath) const @safe
    {
        import std.path : baseName;
        return baseName(filePath) == "package.json";
    }
    
    override string description() const pure nothrow @safe
    {
        return "Migrates npm package.json to Builderfile format";
    }
    
    override string[] supportedFeatures() const pure nothrow @safe
    {
        return [
            "Main entry point",
            "Scripts (build, test, etc.)",
            "Dependencies",
            "TypeScript projects",
            "JavaScript projects"
        ];
    }
    
    override string[] limitations() const pure nothrow @safe
    {
        return [
            "Complex webpack/rollup configs need manual review",
            "Monorepo workspaces require separate migration",
            "NPM scripts are converted to Builder targets"
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
            JSONValue pkg = parseJSON(content);
            
            // Determine if TypeScript or JavaScript
            bool isTypeScript = false;
            if ("devDependencies" in pkg)
            {
                auto devDeps = pkg["devDependencies"].object;
                isTypeScript = ("typescript" in devDeps) !is null;
            }
            if ("dependencies" in pkg)
            {
                auto deps = pkg["dependencies"].object;
                if (("typescript" in deps) !is null)
                    isTypeScript = true;
            }
            
            string pkgName = "name" in pkg ? pkg["name"].str : "app";
            string main = "main" in pkg ? pkg["main"].str : 
                         isTypeScript ? "src/index.ts" : "src/index.js";
            
            // Create main build target
            MigrationTarget buildTarget;
            buildTarget.name = pkgName;
            buildTarget.type = TargetType.Executable;
            buildTarget.language = isTypeScript ? TargetLanguage.TypeScript : TargetLanguage.JavaScript;
            buildTarget.sources = [main];
            buildTarget.output = "dist/" ~ pkgName ~ (isTypeScript ? ".js" : ".bundle.js");
            
            targets ~= buildTarget;
            
            // Parse scripts section for additional targets
            if ("scripts" in pkg)
            {
                auto scripts = pkg["scripts"].object;
                
                if ("test" in scripts)
                {
                    MigrationTarget testTarget;
                    testTarget.name = pkgName ~ "-test";
                    testTarget.type = TargetType.Test;
                    testTarget.language = buildTarget.language;
                    testTarget.sources = ["**/*.test." ~ (isTypeScript ? "ts" : "js")];
                    testTarget.dependencies = [buildTarget.name];
                    
                    targets ~= testTarget;
                }
                
                // Add warning about other scripts
                foreach (scriptName, scriptValue; scripts)
                {
                    if (scriptName != "build" && scriptName != "test" && scriptName != "start")
                    {
                        warnings ~= MigrationWarning(WarningLevel.Info,
                            "Script '" ~ scriptName ~ "' found: " ~ scriptValue.str,
                            "Consider creating a custom target if needed");
                    }
                }
            }
            
            // Note dependencies
            if ("dependencies" in pkg)
            {
                auto deps = pkg["dependencies"].object;
                if (deps.length > 0)
                {
                    warnings ~= MigrationWarning(WarningLevel.Info,
                        "NPM dependencies: " ~ deps.keys.join(", "),
                        "Run 'npm install' before building");
                }
            }
        }
        catch (JSONException e)
        {
            return Result!(MigrationResult, BuildError).err(
                migrationError("Invalid JSON in package.json: " ~ e.msg, inputPath));
        }
        
        MigrationResult result;
        result.targets = targets;
        result.warnings = warnings;
        result.success = true;
        
        return Result!(MigrationResult, BuildError).ok(result);
    }
}

