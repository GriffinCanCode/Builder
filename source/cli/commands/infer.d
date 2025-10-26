module cli.commands.infer;

import std.stdio;
import std.path;
import std.conv;
import analysis.detection.inference;
import analysis.detection.templates;
import analysis.detection.detector;
import utils.logging.logger;

/// Infer command - shows what targets would be auto-detected
struct InferCommand
{
    /// Execute the infer command
    static void execute(string projectDir = ".")
    {
        Logger.info("Analyzing project structure for zero-config inference...\n");
        
        // Run inference
        auto inference = new TargetInference(projectDir);
        auto targets = inference.inferTargets();
        
        if (targets.empty)
        {
            Logger.warning("No targets could be inferred from project structure");
            Logger.info("Consider running 'builder init' to create a Builderfile manually");
            return;
        }
        
        writeln();
        Logger.success("Would infer the following targets:\n");
        
        // Display each inferred target
        foreach (target; targets)
        {
            writeln("┌─ Target: ", target.name);
            writeln("│  Type: ", target.type);
            writeln("│  Language: ", target.language);
            writeln("│  Sources: ", target.sources.length, " file(s)");
            
            if (target.sources.length <= 5)
            {
                foreach (source; target.sources)
                {
                    writeln("│    • ", baseName(source));
                }
            }
            else
            {
                foreach (source; target.sources[0..3])
                {
                    writeln("│    • ", baseName(source));
                }
                writeln("│    • ... and ", target.sources.length - 3, " more");
            }
            
            if (!target.langConfig.empty)
            {
                writeln("│  Config:");
                foreach (key, value; target.langConfig)
                {
                    writeln("│    ", key, ": ", value);
                }
            }
            
            writeln("└─");
            writeln();
        }
        
        Logger.info("To build using zero-config mode:");
        Logger.info("  builder build    # Automatically infers and builds targets");
        writeln();
        Logger.info("To generate a Builderfile based on this inference:");
        Logger.info("  builder init     # Creates Builderfile with detected configuration\n");
    }
}

