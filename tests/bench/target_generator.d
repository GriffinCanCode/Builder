module tests.bench.target_generator;

import std.stdio;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.random;
import std.string;
import std.format;
import std.math : pow;
import std.datetime;

/// Naming convention styles for realistic variety
enum NamingStyle
{
    CamelCase,       // MyComponent
    PascalCase,      // MyComponent (same as CamelCase for classes)
    SnakeCase,       // my_component
    KebabCase,       // my-component
    ScreamingSnake,  // MY_COMPONENT
    FlatCase,        // mycomponent
    DotCase          // my.component
}

/// Project structure types
enum ProjectType
{
    Monorepo,        // Large monorepo with many packages
    Microservices,   // Service-oriented architecture
    Library,         // Library with many modules
    Application,     // Large application with components
    Mixed            // Combination of above
}

/// Language distribution for realistic multi-language projects
struct LanguageDistribution
{
    double typescript = 0.40;
    double python = 0.25;
    double rust = 0.15;
    double go = 0.10;
    double cpp = 0.05;
    double java = 0.05;
}

/// Configuration for target generation
struct GeneratorConfig
{
    size_t targetCount;              // Total number of targets
    ProjectType projectType;          // Type of project structure
    LanguageDistribution languages;   // Language distribution
    double avgDepsPerTarget = 3.5;    // Average dependencies per target
    double circularityRisk = 0.02;    // Probability of creating cycles (should be low)
    size_t maxDepth = 20;             // Maximum dependency depth
    double libToExecRatio = 0.7;      // Ratio of libraries to executables
    bool generateSources = true;      // Actually write source files
    string outputDir;                 // Output directory
}

/// Generated target metadata
struct GeneratedTarget
{
    string id;
    string name;
    string type;    // "library" or "executable"
    string language;
    string[] sources;
    string[] deps;
    NamingStyle namingStyle;
    int layer;      // Dependency layer (0 = no deps, 1 = depends on layer 0, etc)
}

/// Target generator for benchmarking
class TargetGenerator
{
    private GeneratorConfig config;
    private GeneratedTarget[] targets;
    private Random rng;
    private string[int] targetsByLayer;  // Index targets by layer for dependency selection
    
    this(GeneratorConfig config)
    {
        this.config = config;
        this.rng = Random(unpredictableSeed);
    }
    
    /// Generate all targets with realistic dependency graph
    GeneratedTarget[] generate()
    {
        writeln("\x1b[36m[GENERATOR]\x1b[0m Generating ", config.targetCount, " targets...");
        
        // Phase 1: Generate target names and types
        generateTargetMetadata();
        
        // Phase 2: Create layered dependency graph (prevents cycles)
        generateDependencyGraph();
        
        // Phase 3: Write Builderfile and source files
        if (config.generateSources)
        {
            writeProjectFiles();
        }
        
        writeln("\x1b[32m✓\x1b[0m Generated ", targets.length, " targets");
        printStatistics();
        
        return targets;
    }
    
    /// Generate target metadata (names, types, languages)
    private void generateTargetMetadata()
    {
        writeln("  Phase 1/3: Generating target metadata...");
        
        auto libCount = cast(size_t)(config.targetCount * config.libToExecRatio);
        auto execCount = config.targetCount - libCount;
        
        // Generate libraries first (lower layers)
        foreach (i; 0 .. libCount)
        {
            auto target = GeneratedTarget();
            target.id = generateTargetId(i);
            target.name = generateTargetName(i);
            target.type = "library";
            target.language = selectLanguage();
            target.namingStyle = selectNamingStyle();
            target.sources = generateSourcePaths(target);
            targets ~= target;
        }
        
        // Generate executables (higher layers)
        foreach (i; 0 .. execCount)
        {
            auto target = GeneratedTarget();
            target.id = generateTargetId(libCount + i);
            target.name = generateTargetName(libCount + i);
            target.type = "executable";
            target.language = selectLanguage();
            target.namingStyle = selectNamingStyle();
            target.sources = generateSourcePaths(target);
            targets ~= target;
        }
        
        writeln("    Generated ", libCount, " libraries and ", execCount, " executables");
    }
    
    /// Generate realistic dependency graph using layered approach (prevents cycles)
    private void generateDependencyGraph()
    {
        writeln("  Phase 2/3: Generating dependency graph...");
        
        // Assign targets to layers
        foreach (ref target; targets)
        {
            // Libraries tend to be in lower layers, executables in higher layers
            if (target.type == "library")
            {
                // Exponential distribution favoring lower layers
                target.layer = cast(int)(config.maxDepth * (1.0 - pow(uniform01(rng), 2.0)));
            }
            else
            {
                // Executables in higher layers
                target.layer = cast(int)(config.maxDepth * 0.5 + config.maxDepth * 0.5 * uniform01(rng));
            }
            target.layer = min(target.layer, cast(int)config.maxDepth - 1);
        }
        
        // Build index of targets by layer for efficient lookup
        int[][int] targetIdxByLayer;
        foreach (idx, target; targets)
        {
            targetIdxByLayer[target.layer] ~= cast(int)idx;
        }
        
        // Generate dependencies (only from higher to lower layers - prevents cycles)
        size_t totalDeps = 0;
        foreach (ref target; targets)
        {
            auto depCount = cast(size_t)(max(0.0, 
                normal(rng, config.avgDepsPerTarget, config.avgDepsPerTarget * 0.5)));
            
            // Executables tend to have more dependencies
            if (target.type == "executable")
                depCount = cast(size_t)(depCount * 1.5);
            
            // Select dependencies from lower layers
            foreach (_; 0 .. depCount)
            {
                // Select a layer lower than current
                if (target.layer == 0) break;
                
                auto depLayer = uniform(0, target.layer, rng);
                if (depLayer !in targetIdxByLayer || targetIdxByLayer[depLayer].empty)
                    continue;
                
                // Pick random target from that layer
                auto candidateIdx = targetIdxByLayer[depLayer].choice(rng);
                auto depTarget = targets[candidateIdx];
                
                // Avoid self-dependency and duplicates
                if (depTarget.id != target.id && !target.deps.canFind(depTarget.id))
                {
                    target.deps ~= depTarget.id;
                    totalDeps++;
                }
            }
        }
        
        writeln("    Generated ", totalDeps, " dependency edges");
        writeln("    Average deps per target: ", format("%.2f", cast(double)totalDeps / targets.length));
        writeln("    Max layer depth: ", targets.map!(t => t.layer).maxElement);
    }
    
    /// Write Builderfile and source files to disk
    private void writeProjectFiles()
    {
        writeln("  Phase 3/3: Writing project files...");
        
        // Create output directory
        if (!exists(config.outputDir))
            mkdirRecurse(config.outputDir);
        
        // Write Builderspace
        writeBuilderspace();
        
        // Write Builderfile in chunks (for very large files)
        writeBuilderfile();
        
        // Write source files
        writeSourceFiles();
        
        writeln("    Wrote files to: ", config.outputDir);
    }
    
    /// Write Builderspace file
    private void writeBuilderspace()
    {
        auto path = buildPath(config.outputDir, "Builderspace");
        auto f = File(path, "w");
        f.writeln("workspace {");
        f.writeln("    name: \"benchmark-workspace\";");
        f.writeln("    version: \"1.0.0\";");
        f.writeln("}");
        f.close();
    }
    
    /// Write Builderfile with all targets
    private void writeBuilderfile()
    {
        auto path = buildPath(config.outputDir, "Builderfile");
        auto f = File(path, "w");
        
        f.writeln("// Auto-generated Builderfile for benchmarking");
        f.writeln("// Targets: ", config.targetCount);
        f.writeln("// Generated: ", Clock.currTime());
        f.writeln();
        
        // Write targets in chunks to avoid memory issues
        foreach (i, target; targets)
        {
            writeTargetDefinition(f, target);
            
            // Progress indicator
            if ((i + 1) % 10000 == 0)
            {
                writeln("      Wrote ", i + 1, " / ", targets.length, " targets");
            }
        }
        
        f.close();
    }
    
    /// Write single target definition to file
    private void writeTargetDefinition(File f, in GeneratedTarget target)
    {
        f.writeln("target(\"", target.id, "\") {");
        f.writeln("    type: ", target.type, ";");
        f.writeln("    language: ", target.language, ";");
        f.write("    sources: [");
        foreach (idx, src; target.sources)
        {
            f.write("\"", src, "\"");
            if (idx < target.sources.length - 1)
                f.write(", ");
        }
        f.writeln("];");
        
        if (!target.deps.empty)
        {
            f.write("    deps: [");
            foreach (idx, dep; target.deps)
            {
                f.write("\":", dep, "\"");
                if (idx < target.deps.length - 1)
                    f.write(", ");
            }
            f.writeln("];");
        }
        
        f.writeln("}");
        f.writeln();
    }
    
    /// Write source files for all targets
    private void writeSourceFiles()
    {
        size_t filesWritten = 0;
        
        foreach (target; targets)
        {
            foreach (srcPath; target.sources)
            {
                auto fullPath = buildPath(config.outputDir, srcPath);
                auto dirPath = dirName(fullPath);
                
                if (!exists(dirPath))
                    mkdirRecurse(dirPath);
                
                writeSourceFile(fullPath, target);
                filesWritten++;
                
                if (filesWritten % 10000 == 0)
                {
                    writeln("      Wrote ", filesWritten, " source files");
                }
            }
        }
        
        writeln("    Wrote ", filesWritten, " source files");
    }
    
    /// Write a single source file with realistic content
    private void writeSourceFile(string path, in GeneratedTarget target)
    {
        auto f = File(path, "w");
        
        switch (target.language)
        {
            case "typescript":
                writeTypeScriptSource(f, target);
                break;
            case "python":
                writePythonSource(f, target);
                break;
            case "rust":
                writeRustSource(f, target);
                break;
            case "go":
                writeGoSource(f, target);
                break;
            case "cpp":
                writeCppSource(f, target);
                break;
            case "java":
                writeJavaSource(f, target);
                break;
            default:
                f.writeln("// Generated source for ", target.name);
        }
        
        f.close();
    }
    
    // Language-specific source generators
    
    private void writeTypeScriptSource(File f, in GeneratedTarget target)
    {
        f.writeln("// Auto-generated TypeScript source");
        foreach (dep; target.deps)
        {
            f.writeln("import { ", dep, " } from '..", dep, "';");
        }
        f.writeln();
        f.writeln("export interface ", target.name, "Config {");
        f.writeln("  name: string;");
        f.writeln("  version: string;");
        f.writeln("}");
        f.writeln();
        f.writeln("export class ", target.name, " {");
        f.writeln("  constructor(private config: ", target.name, "Config) {}");
        f.writeln("  execute(): void {");
        f.writeln("    console.log('Executing ", target.name, "');");
        f.writeln("  }");
        f.writeln("}");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("const instance = new ", target.name, "({ name: '", target.name, "', version: '1.0.0' });");
            f.writeln("instance.execute();");
        }
    }
    
    private void writePythonSource(File f, in GeneratedTarget target)
    {
        f.writeln("# Auto-generated Python source");
        foreach (dep; target.deps)
        {
            f.writeln("from ", dep, " import ", dep);
        }
        f.writeln();
        f.writeln("class ", target.name, ":");
        f.writeln("    def __init__(self, name: str, version: str):");
        f.writeln("        self.name = name");
        f.writeln("        self.version = version");
        f.writeln();
        f.writeln("    def execute(self) -> None:");
        f.writeln("        print(f'Executing {self.name}')");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("if __name__ == '__main__':");
            f.writeln("    instance = ", target.name, "('", target.name, "', '1.0.0')");
            f.writeln("    instance.execute()");
        }
    }
    
    private void writeRustSource(File f, in GeneratedTarget target)
    {
        f.writeln("// Auto-generated Rust source");
        foreach (dep; target.deps)
        {
            f.writeln("use ", dep, ";");
        }
        f.writeln();
        f.writeln("pub struct ", target.name, " {");
        f.writeln("    name: String,");
        f.writeln("    version: String,");
        f.writeln("}");
        f.writeln();
        f.writeln("impl ", target.name, " {");
        f.writeln("    pub fn new(name: String, version: String) -> Self {");
        f.writeln("        Self { name, version }");
        f.writeln("    }");
        f.writeln();
        f.writeln("    pub fn execute(&self) {");
        f.writeln("        println!(\"Executing {}\", self.name);");
        f.writeln("    }");
        f.writeln("}");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("fn main() {");
            f.writeln("    let instance = ", target.name, "::new(\"", target.name, "\".to_string(), \"1.0.0\".to_string());");
            f.writeln("    instance.execute();");
            f.writeln("}");
        }
    }
    
    private void writeGoSource(File f, in GeneratedTarget target)
    {
        f.writeln("// Auto-generated Go source");
        f.writeln("package ", target.name.toLower());
        f.writeln();
        foreach (dep; target.deps)
        {
            f.writeln("import \"", dep, "\"");
        }
        f.writeln();
        f.writeln("type ", target.name, " struct {");
        f.writeln("    Name    string");
        f.writeln("    Version string");
        f.writeln("}");
        f.writeln();
        f.writeln("func New", target.name, "(name, version string) *", target.name, " {");
        f.writeln("    return &", target.name, "{Name: name, Version: version}");
        f.writeln("}");
        f.writeln();
        f.writeln("func (c *", target.name, ") Execute() {");
        f.writeln("    println(\"Executing\", c.Name)");
        f.writeln("}");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("func main() {");
            f.writeln("    instance := New", target.name, "(\"", target.name, "\", \"1.0.0\")");
            f.writeln("    instance.Execute()");
            f.writeln("}");
        }
    }
    
    private void writeCppSource(File f, in GeneratedTarget target)
    {
        f.writeln("// Auto-generated C++ source");
        f.writeln("#include <iostream>");
        f.writeln("#include <string>");
        foreach (dep; target.deps)
        {
            f.writeln("#include \"", dep, ".hpp\"");
        }
        f.writeln();
        f.writeln("class ", target.name, " {");
        f.writeln("private:");
        f.writeln("    std::string name;");
        f.writeln("    std::string version;");
        f.writeln();
        f.writeln("public:");
        f.writeln("    ", target.name, "(const std::string& n, const std::string& v)");
        f.writeln("        : name(n), version(v) {}");
        f.writeln();
        f.writeln("    void execute() {");
        f.writeln("        std::cout << \"Executing \" << name << std::endl;");
        f.writeln("    }");
        f.writeln("};");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("int main() {");
            f.writeln("    ", target.name, " instance(\"", target.name, "\", \"1.0.0\");");
            f.writeln("    instance.execute();");
            f.writeln("    return 0;");
            f.writeln("}");
        }
    }
    
    private void writeJavaSource(File f, in GeneratedTarget target)
    {
        f.writeln("// Auto-generated Java source");
        f.writeln("package benchmark;");
        f.writeln();
        foreach (dep; target.deps)
        {
            f.writeln("import benchmark.", dep, ";");
        }
        f.writeln();
        f.writeln("public class ", target.name, " {");
        f.writeln("    private String name;");
        f.writeln("    private String version;");
        f.writeln();
        f.writeln("    public ", target.name, "(String name, String version) {");
        f.writeln("        this.name = name;");
        f.writeln("        this.version = version;");
        f.writeln("    }");
        f.writeln();
        f.writeln("    public void execute() {");
        f.writeln("        System.out.println(\"Executing \" + name);");
        f.writeln("    }");
        
        if (target.type == "executable")
        {
            f.writeln();
            f.writeln("    public static void main(String[] args) {");
            f.writeln("        ", target.name, " instance = new ", target.name, "(\"", target.name, "\", \"1.0.0\");");
            f.writeln("        instance.execute();");
            f.writeln("    }");
        }
        
        f.writeln("}");
    }
    
    // Helper methods
    
    private string generateTargetId(size_t index)
    {
        final switch (config.projectType)
        {
            case ProjectType.Monorepo:
                // packages/package-name-123
                return format("packages/pkg-%05d", index);
            case ProjectType.Microservices:
                // services/service-name-123
                return format("services/svc-%05d", index);
            case ProjectType.Library:
                // modules/module-name-123
                return format("modules/mod-%05d", index);
            case ProjectType.Application:
                // components/component-name-123
                return format("components/comp-%05d", index);
            case ProjectType.Mixed:
                // Mix of all types
                auto types = ["packages/pkg", "services/svc", "modules/mod", "components/comp"];
                return format("%s-%05d", types[index % $], index);
        }
    }
    
    private string generateTargetName(size_t index)
    {
        // Generate realistic names with variety
        static immutable prefixes = [
            "Core", "Data", "Auth", "Api", "Service", "Handler", "Manager", 
            "Processor", "Controller", "Provider", "Factory", "Repository",
            "Adapter", "Connector", "Client", "Server", "Worker", "Queue",
            "Cache", "Storage", "Network", "Security", "Util", "Helper"
        ];
        
        static immutable suffixes = [
            "Engine", "Module", "Component", "System", "Framework", "Library",
            "Package", "Bundle", "Plugin", "Extension", "Interface", "Impl",
            "Base", "Abstract", "Concrete", "Proxy", "Decorator", "Strategy"
        ];
        
        auto prefix = prefixes[index % prefixes.length];
        auto suffix = suffixes[(index / prefixes.length) % suffixes.length];
        return format("%s%s%03d", prefix, suffix, index % 1000);
    }
    
    private NamingStyle selectNamingStyle()
    {
        // Realistic distribution of naming styles
        auto r = uniform01(rng);
        if (r < 0.40) return NamingStyle.CamelCase;
        if (r < 0.70) return NamingStyle.SnakeCase;
        if (r < 0.85) return NamingStyle.KebabCase;
        if (r < 0.93) return NamingStyle.PascalCase;
        if (r < 0.97) return NamingStyle.FlatCase;
        return NamingStyle.DotCase;
    }
    
    private string selectLanguage()
    {
        auto r = uniform01(rng);
        auto cum = 0.0;
        
        cum += config.languages.typescript;
        if (r < cum) return "typescript";
        
        cum += config.languages.python;
        if (r < cum) return "python";
        
        cum += config.languages.rust;
        if (r < cum) return "rust";
        
        cum += config.languages.go;
        if (r < cum) return "go";
        
        cum += config.languages.cpp;
        if (r < cum) return "cpp";
        
        return "java";
    }
    
    private string[] generateSourcePaths(in GeneratedTarget target)
    {
        // Generate 1-3 source files per target (realistic)
        auto fileCount = uniform(1, 4, rng);
        string[] sources;
        
        auto basePath = target.id;
        auto ext = getLanguageExtension(target.language);
        
        foreach (i; 0 .. fileCount)
        {
            auto fileName = i == 0 ? "index" : format("module_%d", i);
            sources ~= buildPath(basePath, "src", fileName ~ ext);
        }
        
        return sources;
    }
    
    private string getLanguageExtension(string language)
    {
        switch (language)
        {
            case "typescript": return ".ts";
            case "python": return ".py";
            case "rust": return ".rs";
            case "go": return ".go";
            case "cpp": return ".cpp";
            case "java": return ".java";
            default: return ".txt";
        }
    }
    
    /// Print generation statistics
    private void printStatistics()
    {
        writeln("\n\x1b[36m[STATISTICS]\x1b[0m");
        
        // Language distribution
        int[string] langCounts;
        foreach (target; targets)
            langCounts[target.language]++;
        
        writeln("  Languages:");
        foreach (lang, count; langCounts)
            writeln(format("    %s: %d (%.1f%%)", lang, count, 100.0 * count / targets.length));
        
        // Type distribution
        auto libCount = targets.count!(t => t.type == "library");
        auto execCount = targets.length - libCount;
        writeln(format("  Types: %d libraries (%.1f%%), %d executables (%.1f%%)", 
            libCount, 100.0 * libCount / targets.length,
            execCount, 100.0 * execCount / targets.length));
        
        // Dependency statistics
        auto totalDeps = targets.map!(t => t.deps.length).sum;
        auto maxDeps = targets.map!(t => t.deps.length).maxElement;
        writeln(format("  Dependencies: total=%d, avg=%.2f, max=%d",
            totalDeps, cast(double)totalDeps / targets.length, maxDeps));
        
        // Layer statistics
        auto maxLayer = targets.map!(t => t.layer).maxElement;
        writeln(format("  Layers: max=%d", maxLayer));
    }
    
    /// Get generated targets
    GeneratedTarget[] getTargets()
    {
        return targets;
    }
}

// Helper function for normal distribution
private double normal(ref Random rng, double mean, double stddev)
{
    // Box-Muller transform
    auto u1 = uniform01(rng);
    auto u2 = uniform01(rng);
    import std.math : sqrt, log, PI, cos;
    return mean + stddev * sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2);
}

