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
        
        bool builderfileExists = std.file.exists(builderfilePath);
        bool builderspaceExists = std.file.exists(builderspacePath);
        
        if (builderfileExists && builderspaceExists)
        {
            Logger.error("Builderfile and Builderspace already exist");
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
        
        // Show next steps
        writeln();
        Logger.success("Initialization complete! 🎉\n");
        Logger.info("Next steps:");
        Logger.info("  1. Review and customize your Builderfile");
        Logger.info("  2. Run 'builder build' to build your project");
        Logger.info("  3. Run 'builder graph' to visualize dependencies\n");
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

