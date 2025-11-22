module engine.runtime.hermetic.determinism.repair;

import std.algorithm : canFind, map, filter;
import std.array : array;
import std.conv : to;
import std.string : format;
import engine.runtime.hermetic.determinism.detector;
import engine.runtime.hermetic.determinism.enforcer;

/// Repair suggestion priority
enum RepairPriority
{
    Critical,   // Must fix for determinism
    High,       // Strongly recommended
    Medium,     // Recommended
    Low         // Optional optimization
}

/// Repair action type
enum RepairActionType
{
    AddCompilerFlag,
    RemoveCompilerFlag,
    SetEnvironmentVariable,
    ModifyBuildScript,
    UpgradeToolchain,
    DisableFeature
}

/// Specific repair action
struct RepairAction
{
    RepairActionType type;
    string target;          // What to modify (flag, var name, etc.)
    string value;           // New value or flag to add
    string description;     // Human-readable description
    RepairPriority priority;
    
    /// Format as command-line suggestion
    string toCommandLine() @safe const
    {
        final switch (type)
        {
            case RepairActionType.AddCompilerFlag:
                return "Add compiler flag: " ~ value;
            
            case RepairActionType.RemoveCompilerFlag:
                return "Remove compiler flag: " ~ target;
            
            case RepairActionType.SetEnvironmentVariable:
                return "export " ~ target ~ "=" ~ value;
            
            case RepairActionType.ModifyBuildScript:
                return "Modify build script: " ~ description;
            
            case RepairActionType.UpgradeToolchain:
                return "Upgrade toolchain: " ~ description;
            
            case RepairActionType.DisableFeature:
                return "Disable feature: " ~ target;
        }
    }
}

/// Complete repair suggestion with actions and explanation
struct RepairSuggestion
{
    NonDeterminismSource source;
    string problem;
    RepairAction[] actions;
    string explanation;
    string[] references;     // URLs to documentation
    RepairPriority priority;
    
    /// Get formatted suggestion for display
    string format() @safe const
    {
        import std.array : Appender;
        
        Appender!string result;
        
        // Header
        result ~= "\n";
        result ~= prioritySymbol() ~ " ";
        result ~= problem;
        result ~= "\n\n";
        
        // Explanation
        if (!explanation.empty)
        {
            result ~= "  " ~ explanation ~ "\n\n";
        }
        
        // Actions
        if (actions.length > 0)
        {
            result ~= "  Suggested fixes:\n";
            foreach (i, action; actions)
            {
                result ~= "    " ~ (i + 1).to!string ~ ". " ~ 
                    action.toCommandLine() ~ "\n";
                if (!action.description.empty)
                    result ~= "       " ~ action.description ~ "\n";
            }
            result ~= "\n";
        }
        
        // References
        if (references.length > 0)
        {
            result ~= "  References:\n";
            foreach (ref_; references)
            {
                result ~= "    • " ~ ref_ ~ "\n";
            }
        }
        
        return result.data;
    }
    
    private string prioritySymbol() @safe const pure nothrow
    {
        final switch (priority)
        {
            case RepairPriority.Critical: return "🔴";
            case RepairPriority.High:     return "🟠";
            case RepairPriority.Medium:   return "🟡";
            case RepairPriority.Low:      return "🟢";
        }
    }
}

/// Repair suggestion engine
/// 
/// Analyzes detection results and generates actionable repair suggestions
/// with specific compiler flags, environment variables, and build script
/// modifications needed to achieve determinism.
struct RepairEngine
{
    /// Generate repair suggestions from detection results
    static RepairSuggestion[] generateSuggestions(
        DetectionResult[] detections
    ) @safe
    {
        RepairSuggestion[] suggestions;
        
        foreach (detection; detections)
        {
            auto suggestion = generateSuggestion(detection);
            if (suggestion.actions.length > 0)
                suggestions ~= suggestion;
        }
        
        return suggestions;
    }
    
    /// Generate repair suggestions from violations
    static RepairSuggestion[] generateFromViolations(
        DeterminismViolation[] violations
    ) @safe
    {
        RepairSuggestion[] suggestions;
        
        foreach (violation; violations)
        {
            auto suggestion = generateFromViolation(violation);
            suggestions ~= suggestion;
        }
        
        return suggestions;
    }
    
    /// Generate comprehensive repair plan
    static string generateRepairPlan(
        DetectionResult[] detections,
        DeterminismViolation[] violations
    ) @safe
    {
        import std.array : Appender;
        
        Appender!string plan;
        
        plan ~= "═══════════════════════════════════════════════════════════\n";
        plan ~= "           DETERMINISTIC BUILD REPAIR PLAN\n";
        plan ~= "═══════════════════════════════════════════════════════════\n\n";
        
        // Generate suggestions from detections
        auto detectionSuggestions = generateSuggestions(detections);
        
        // Generate suggestions from violations
        auto violationSuggestions = generateFromViolations(violations);
        
        // Combine and sort by priority
        import std.algorithm : sort;
        auto allSuggestions = detectionSuggestions ~ violationSuggestions;
        allSuggestions.sort!((a, b) => a.priority < b.priority);
        
        if (allSuggestions.length == 0)
        {
            plan ~= "✓ No issues detected. Build appears deterministic.\n";
            return plan.data;
        }
        
        plan ~= "Found " ~ allSuggestions.length.to!string ~ " potential issues:\n\n";
        
        // Group by priority
        foreach (priority; [RepairPriority.Critical, RepairPriority.High, 
                           RepairPriority.Medium, RepairPriority.Low])
        {
            auto group = allSuggestions.filter!(s => s.priority == priority).array;
            if (group.length == 0)
                continue;
            
            plan ~= "───────────────────────────────────────────────────────────\n";
            plan ~= priorityLabel(priority) ~ " (" ~ group.length.to!string ~ " issues)\n";
            plan ~= "───────────────────────────────────────────────────────────\n";
            
            foreach (suggestion; group)
            {
                plan ~= suggestion.format();
            }
        }
        
        plan ~= "\n═══════════════════════════════════════════════════════════\n";
        plan ~= "Apply these fixes and rebuild to verify determinism.\n";
        plan ~= "═══════════════════════════════════════════════════════════\n";
        
        return plan.data;
    }
    
    private:
    
    /// Generate suggestion from single detection
    static RepairSuggestion generateSuggestion(DetectionResult detection) @safe
    {
        RepairSuggestion suggestion;
        suggestion.source = detection.source;
        suggestion.problem = detection.description;
        suggestion.explanation = detection.explanation;
        
        // Add compiler flag actions
        foreach (flag; detection.compilerFlags)
        {
            RepairAction action;
            action.type = RepairActionType.AddCompilerFlag;
            action.value = flag;
            action.description = "Add to compiler command";
            action.priority = RepairPriority.High;
            suggestion.actions ~= action;
        }
        
        // Add environment variable actions
        foreach (env; detection.envVars)
        {
            import std.string : split;
            auto parts = env.split("=");
            if (parts.length == 2)
            {
                RepairAction action;
                action.type = RepairActionType.SetEnvironmentVariable;
                action.target = parts[0];
                action.value = parts[1];
                action.description = "Set before build";
                action.priority = RepairPriority.High;
                suggestion.actions ~= action;
            }
        }
        
        // Set overall priority
        suggestion.priority = determinePriority(detection.source);
        
        // Add references
        suggestion.references = getReferences(detection.source);
        
        return suggestion;
    }
    
    /// Generate suggestion from violation
    static RepairSuggestion generateFromViolation(
        DeterminismViolation violation
    ) @safe
    {
        RepairSuggestion suggestion;
        suggestion.problem = violation.description;
        suggestion.explanation = violation.suggestion;
        suggestion.priority = RepairPriority.High;
        
        // Add action based on violation source
        if (violation.source == "output_mismatch")
        {
            RepairAction action;
            action.type = RepairActionType.SetEnvironmentVariable;
            action.target = "BUILDER_DETERMINISM";
            action.value = "strict";
            action.description = "Enable strict determinism mode";
            action.priority = RepairPriority.Critical;
            suggestion.actions ~= action;
        }
        
        return suggestion;
    }
    
    /// Determine priority based on source
    static RepairPriority determinePriority(NonDeterminismSource source) @safe pure nothrow
    {
        final switch (source)
        {
            case NonDeterminismSource.Timestamp:
                return RepairPriority.High;
            
            case NonDeterminismSource.RandomValue:
                return RepairPriority.Critical;
            
            case NonDeterminismSource.ThreadScheduling:
                return RepairPriority.High;
            
            case NonDeterminismSource.CompilerVersion:
                return RepairPriority.Medium;
            
            case NonDeterminismSource.FileOrdering:
                return RepairPriority.Medium;
            
            case NonDeterminismSource.PointerAddress:
                return RepairPriority.High;
            
            case NonDeterminismSource.ASLR:
                return RepairPriority.Low;
            
            case NonDeterminismSource.BuildPath:
                return RepairPriority.High;
            
            case NonDeterminismSource.Unknown:
                return RepairPriority.Low;
        }
    }
    
    /// Get documentation references for source
    static string[] getReferences(NonDeterminismSource source) @safe pure nothrow
    {
        final switch (source)
        {
            case NonDeterminismSource.Timestamp:
                return [
                    "https://reproducible-builds.org/docs/timestamps/",
                    "https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html"
                ];
            
            case NonDeterminismSource.RandomValue:
                return [
                    "https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html",
                    "https://reproducible-builds.org/docs/randomness/"
                ];
            
            case NonDeterminismSource.BuildPath:
                return [
                    "https://reproducible-builds.org/docs/build-path/",
                    "https://gcc.gnu.org/onlinedocs/gcc/Debugging-Options.html"
                ];
            
            case NonDeterminismSource.ThreadScheduling:
            case NonDeterminismSource.CompilerVersion:
            case NonDeterminismSource.FileOrdering:
            case NonDeterminismSource.PointerAddress:
            case NonDeterminismSource.ASLR:
            case NonDeterminismSource.Unknown:
                return ["https://reproducible-builds.org/"];
        }
    }
    
    /// Get priority label
    static string priorityLabel(RepairPriority priority) @safe pure nothrow
    {
        final switch (priority)
        {
            case RepairPriority.Critical: return "🔴 CRITICAL";
            case RepairPriority.High:     return "🟠 HIGH PRIORITY";
            case RepairPriority.Medium:   return "🟡 MEDIUM PRIORITY";
            case RepairPriority.Low:      return "🟢 LOW PRIORITY";
        }
    }
}

@safe unittest
{
    import std.stdio : writeln;
    
    writeln("Testing repair engine...");
    
    // Create test detection
    DetectionResult detection;
    detection.source = NonDeterminismSource.RandomValue;
    detection.description = "Missing -frandom-seed flag";
    detection.compilerFlags = ["-frandom-seed=42"];
    detection.explanation = "GCC uses random seeds";
    
    // Generate suggestion
    auto suggestions = RepairEngine.generateSuggestions([detection]);
    assert(suggestions.length == 1);
    assert(suggestions[0].actions.length == 1);
    assert(suggestions[0].actions[0].value == "-frandom-seed=42");
    
    // Generate repair plan
    auto plan = RepairEngine.generateRepairPlan([detection], []);
    assert(plan.canFind("REPAIR PLAN"));
    assert(plan.canFind("-frandom-seed=42"));
    
    writeln("✓ Repair engine tests passed");
}

