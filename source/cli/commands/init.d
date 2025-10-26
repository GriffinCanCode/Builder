module cli.commands.init;

import std.stdio;
import std.path;
import std.string : format;
import std.algorithm;
import std.array : replicate;
import std.range : empty;
import analysis.detection.detector;
import analysis.detection.templates;
import utils.logging.logger;

static import std.file;

/// Initialize command - creates Builderfile and Builderspace
struct InitCommand
{
    /// Execute the init command
    static void execute(string projectDir = ".")
    {
        Logger.info("Initializing Builder project...\n");
        
        // Check if files already exist
        immutable builderfilePath = buildPath(projectDir, "Builderfile");
        immutable builderspacePath = buildPath(projectDir, "Builderspace");
        immutable builderignorePath = buildPath(projectDir, ".builderignore");
        
        bool builderfileExists = std.file.exists(builderfilePath);
        bool builderspaceExists = std.file.exists(builderspacePath);
        bool builderignoreExists = std.file.exists(builderignorePath);
        
        if (builderfileExists && builderspaceExists && builderignoreExists)
        {
            Logger.error("Builderfile, Builderspace, and .builderignore already exist");
            Logger.info("Use --force to overwrite existing files");
            return;
        }
        
        // Detect project structure
        Logger.info("Scanning project directory...");
        auto detector = new ProjectDetector(projectDir);
        auto metadata = detector.detect();
        
        if (metadata.languages.empty)
        {
            Logger.warning("No supported languages detected");
            Logger.info("Creating generic Builderfile template");
        }
        else
        {
            Logger.success(format("Detected %d language(s):", metadata.languages.length));
            foreach (langInfo; metadata.languages)
            {
                string frameworkInfo = langInfo.framework != ProjectFramework.None ? 
                    format(" [%s]", langInfo.framework) : "";
                Logger.info(format("  • %s (%.0f%% confidence)%s", 
                    langInfo.language, 
                    langInfo.confidence * 100,
                    frameworkInfo
                ));
                
                if (!langInfo.manifestFiles.empty)
                {
                    foreach (manifest; langInfo.manifestFiles)
                    {
                        Logger.debug_("    Found: " ~ baseName(manifest));
                    }
                }
            }
            writeln();
        }
        
        // Generate templates
        auto generator = new TemplateGenerator(metadata);
        
        // Create Builderfile
        if (!builderfileExists)
        {
            string builderfileContent = generator.generateBuilderfile();
            
            try
            {
                std.file.write(builderfilePath, builderfileContent);
                Logger.success("Created Builderfile");
                
                // Show preview
                showFilePreview("Builderfile", builderfileContent);
            }
            catch (Exception e)
            {
                Logger.error("Failed to create Builderfile: " ~ e.msg);
                return;
            }
        }
        else
        {
            Logger.info("Skipping Builderfile (already exists)");
        }
        
        // Create Builderspace
        if (!builderspaceExists)
        {
            string builderspaceContent = generator.generateBuilderspace();
            
            try
            {
                std.file.write(builderspacePath, builderspaceContent);
                Logger.success("Created Builderspace");
                
                // Show preview
                showFilePreview("Builderspace", builderspaceContent);
            }
            catch (Exception e)
            {
                Logger.error("Failed to create Builderspace: " ~ e.msg);
                return;
            }
        }
        else
        {
            Logger.info("Skipping Builderspace (already exists)");
        }
        
        // Create .builderignore
        if (!builderignoreExists)
        {
            string builderignoreContent = generateBuilderignore(metadata);
            
            try
            {
                std.file.write(builderignorePath, builderignoreContent);
                Logger.success("Created .builderignore");
                
                // Show preview
                showFilePreview(".builderignore", builderignoreContent);
            }
            catch (Exception e)
            {
                Logger.error("Failed to create .builderignore: " ~ e.msg);
                return;
            }
        }
        else
        {
            Logger.info("Skipping .builderignore (already exists)");
        }
        
        // Show next steps
        writeln();
        Logger.success("Initialization complete! 🎉\n");
        Logger.info("Next steps:");
        Logger.info("  1. Review and customize your Builderfile");
        Logger.info("  2. Customize .builderignore to exclude specific directories");
        Logger.info("  3. Run 'builder build' to build your project");
        Logger.info("  4. Run 'builder graph' to visualize dependencies\n");
    }
    
    /// Generate .builderignore content based on detected languages
    private static string generateBuilderignore(ProjectMetadata metadata)
    {
        import config.schema.schema : TargetLanguage;
        
        string content = "# Builder Ignore File\n";
        content ~= "# Patterns listed here will be ignored during source scanning and target detection\n";
        content ~= "# Syntax is similar to .gitignore\n\n";
        
        content ~= "# Version control\n";
        content ~= ".git/\n";
        content ~= ".svn/\n";
        content ~= ".hg/\n\n";
        
        content ~= "# Builder's own cache\n";
        content ~= ".builder-cache/\n\n";
        
        // Add language-specific patterns based on detected languages
        bool hasJS = false;
        bool hasPython = false;
        bool hasRuby = false;
        bool hasGo = false;
        bool hasRust = false;
        bool hasJVM = false;
        bool hasDotNet = false;
        bool hasElixir = false;
        bool hasCpp = false;
        
        foreach (langInfo; metadata.languages)
        {
            switch (langInfo.language)
            {
                case TargetLanguage.JavaScript:
                case TargetLanguage.TypeScript:
                    hasJS = true;
                    break;
                case TargetLanguage.Python:
                    hasPython = true;
                    break;
                case TargetLanguage.Ruby:
                    hasRuby = true;
                    break;
                case TargetLanguage.Go:
                    hasGo = true;
                    break;
                case TargetLanguage.Rust:
                    hasRust = true;
                    break;
                case TargetLanguage.Java:
                case TargetLanguage.Kotlin:
                case TargetLanguage.Scala:
                    hasJVM = true;
                    break;
                case TargetLanguage.CSharp:
                case TargetLanguage.FSharp:
                    hasDotNet = true;
                    break;
                case TargetLanguage.Elixir:
                    hasElixir = true;
                    break;
                case TargetLanguage.C:
                case TargetLanguage.Cpp:
                    hasCpp = true;
                    break;
                default:
                    break;
            }
        }
        
        if (hasJS)
        {
            content ~= "# JavaScript/TypeScript dependencies\n";
            content ~= "node_modules/\n";
            content ~= "bower_components/\n";
            content ~= ".npm/\n";
            content ~= ".yarn/\n\n";
        }
        
        if (hasPython)
        {
            content ~= "# Python dependencies and cache\n";
            content ~= "venv/\n";
            content ~= ".venv/\n";
            content ~= "env/\n";
            content ~= "__pycache__/\n";
            content ~= "*.pyc\n";
            content ~= "*.pyo\n";
            content ~= ".pytest_cache/\n";
            content ~= ".mypy_cache/\n\n";
        }
        
        if (hasRuby)
        {
            content ~= "# Ruby dependencies\n";
            content ~= "vendor/bundle/\n";
            content ~= ".bundle/\n\n";
        }
        
        if (hasGo)
        {
            content ~= "# Go dependencies\n";
            content ~= "vendor/\n\n";
        }
        
        if (hasRust)
        {
            content ~= "# Rust build artifacts\n";
            content ~= "target/\n";
            content ~= "Cargo.lock\n\n";
        }
        
        if (hasJVM)
        {
            content ~= "# JVM build artifacts and dependencies\n";
            content ~= "target/\n";
            content ~= "build/\n";
            content ~= ".gradle/\n";
            content ~= ".m2/\n";
            content ~= "*.class\n\n";
        }
        
        if (hasDotNet)
        {
            content ~= "# .NET build artifacts\n";
            content ~= "bin/\n";
            content ~= "obj/\n";
            content ~= "packages/\n";
            content ~= "*.dll\n";
            content ~= "*.exe\n\n";
        }
        
        if (hasElixir)
        {
            content ~= "# Elixir dependencies and build\n";
            content ~= "deps/\n";
            content ~= "_build/\n";
            content ~= ".elixir_ls/\n\n";
        }
        
        if (hasCpp)
        {
            content ~= "# C/C++ build artifacts\n";
            content ~= "build/\n";
            content ~= "cmake-build-*/\n";
            content ~= "*.o\n";
            content ~= "*.obj\n";
            content ~= "*.so\n";
            content ~= "*.dll\n\n";
        }
        
        content ~= "# Common build outputs\n";
        content ~= "dist/\n";
        content ~= "out/\n\n";
        
        content ~= "# IDE directories\n";
        content ~= ".idea/\n";
        content ~= ".vscode/\n";
        content ~= ".vs/\n\n";
        
        content ~= "# OS files\n";
        content ~= ".DS_Store\n";
        content ~= "Thumbs.db\n\n";
        
        content ~= "# Temporary files\n";
        content ~= "tmp/\n";
        content ~= "temp/\n";
        content ~= "*.tmp\n";
        content ~= "*.log\n\n";
        
        content ~= "# Custom patterns\n";
        content ~= "# Add your own patterns below:\n";
        
        return content;
    }
    
    /// Show file preview (first few lines)
    private static void showFilePreview(string filename, string content)
    {
        import std.range : take;
        import std.algorithm : splitter;
        
        writeln();
        Logger.info(format("Preview of %s:", filename));
        writeln("┌" ~ "─".replicate(60) ~ "┐");
        
        auto lines = content.splitter('\n').take(15);
        foreach (line; lines)
        {
            // Truncate long lines
            if (line.length > 58)
                line = line[0..55] ~ "...";
            writeln("│ " ~ line ~ " ".replicate(58 - line.length) ~ " │");
        }
        
        writeln("└" ~ "─".replicate(60) ~ "┘");
        writeln();
    }
}

