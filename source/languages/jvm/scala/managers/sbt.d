module languages.jvm.scala.managers.sbt;

import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.process;
import std.regex;
import std.conv;
import utils.logging.logger;
import languages.jvm.scala.core.config;

/// sbt build.sbt metadata
struct SbtMetadata
{
    string name;
    string organization;
    string version_;
    ScalaVersionInfo scalaVersion;
    
    Dependency[] dependencies;
    string[] resolvers;
    string[] plugins;
    string[] settings;
    
    /// Parse from build.sbt file
    static SbtMetadata fromFile(string buildSbtPath)
    {
        if (!exists(buildSbtPath))
            throw new Exception("build.sbt not found at: " ~ buildSbtPath);
        
        string content = readText(buildSbtPath);
        return fromContent(content);
    }
    
    /// Parse from build.sbt content
    static SbtMetadata fromContent(string content)
    {
        SbtMetadata meta;
        
        try
        {
            // Parse name
            auto nameMatch = matchFirst(content, regex(`name\s*:=\s*"([^"]+)"`));
            if (!nameMatch.empty)
                meta.name = nameMatch[1];
            
            // Parse organization
            auto orgMatch = matchFirst(content, regex(`organization\s*:=\s*"([^"]+)"`));
            if (!orgMatch.empty)
                meta.organization = orgMatch[1];
            
            // Parse version
            auto verMatch = matchFirst(content, regex(`version\s*:=\s*"([^"]+)"`));
            if (!verMatch.empty)
                meta.version_ = verMatch[1];
            
            // Parse Scala version
            auto scalaVerMatch = matchFirst(content, regex(`scalaVersion\s*:=\s*"([\d.]+)"`));
            if (!scalaVerMatch.empty)
                meta.scalaVersion = ScalaVersionInfo.parse(scalaVerMatch[1]);
            
            // Parse dependencies
            meta.dependencies = parseDependencies(content);
            
            // Parse resolvers
            meta.resolvers = parseResolvers(content);
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse build.sbt: " ~ e.msg);
        }
        
        return meta;
    }
    
    /// Check if uses Scala.js
    bool usesScalaJS() const
    {
        foreach (plugin; plugins)
        {
            if (plugin.canFind("sbt-scalajs"))
                return true;
        }
        return false;
    }
    
    /// Check if uses Scala Native
    bool usesScalaNative() const
    {
        foreach (plugin; plugins)
        {
            if (plugin.canFind("sbt-scala-native"))
                return true;
        }
        return false;
    }
    
    /// Check if uses sbt-assembly
    bool usesAssembly() const
    {
        foreach (plugin; plugins)
        {
            if (plugin.canFind("sbt-assembly"))
                return true;
        }
        return false;
    }
}

/// sbt dependency
struct Dependency
{
    string organization;
    string name;
    string version_;
    string scope_ = "compile";
    string configuration;
    
    /// Get full coordinate
    string coordinate() const
    {
        string coord = organization ~ ":" ~ name;
        if (!version_.empty)
            coord ~= ":" ~ version_;
        return coord;
    }
}

/// sbt operations
class SbtOps
{
    /// Execute sbt command
    static auto executeSbt(string[] args, string workingDir = ".")
    {
        return execute(["sbt"] ~ args, null, Config.none, size_t.max, workingDir);
    }
    
    /// Compile project
    static bool compile(string projectDir, bool skipTests = false)
    {
        Logger.info("Compiling sbt project");
        
        string[] args = ["compile"];
        if (skipTests)
            args = ["compile", "Test/compile"];
        
        auto result = executeSbt(args, projectDir);
        
        if (result.status != 0)
        {
            Logger.error("sbt compilation failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Package project
    static bool packageProject(string projectDir, bool skipTests = false)
    {
        Logger.info("Packaging sbt project");
        
        string[] args = ["package"];
        if (skipTests)
            args ~= "-DskipTests";
        
        auto result = executeSbt(args, projectDir);
        
        if (result.status != 0)
        {
            Logger.error("sbt packaging failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Run tests
    static bool test(string projectDir)
    {
        Logger.info("Running sbt tests");
        
        auto result = executeSbt(["test"], projectDir);
        
        if (result.status != 0)
        {
            Logger.error("sbt tests failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Clean build
    static bool clean(string projectDir)
    {
        Logger.info("Cleaning sbt project");
        
        auto result = executeSbt(["clean"], projectDir);
        
        return result.status == 0;
    }
    
    /// Update dependencies
    static bool update(string projectDir)
    {
        Logger.info("Updating sbt dependencies");
        
        auto result = executeSbt(["update"], projectDir);
        
        if (result.status != 0)
        {
            Logger.error("sbt update failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Run sbt assembly (fat JAR)
    static bool assembly(string projectDir)
    {
        Logger.info("Creating assembly JAR");
        
        auto result = executeSbt(["assembly"], projectDir);
        
        if (result.status != 0)
        {
            Logger.error("sbt assembly failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Get sbt version
    static string getVersion()
    {
        auto result = execute(["sbt", "sbtVersion"]);
        if (result.status == 0)
        {
            auto match = matchFirst(result.output, regex(`\[info\]\s+([\d.]+)`));
            if (!match.empty)
                return match[1];
        }
        return "";
    }
    
    /// Parse plugins from project/plugins.sbt
    static string[] parsePlugins(string projectDir)
    {
        string[] plugins;
        string pluginsPath = buildPath(projectDir, "project", "plugins.sbt");
        
        if (!exists(pluginsPath))
            return plugins;
        
        try
        {
            auto content = readText(pluginsPath);
            auto pattern = regex(`addSbtPlugin\("([^"]+)"\s*%\s*"([^"]+)"\s*%\s*"([^"]+)"\)`);
            
            foreach (match; matchAll(content, pattern))
            {
                string plugin = match[1] ~ ":" ~ match[2] ~ ":" ~ match[3];
                plugins ~= plugin;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse plugins.sbt: " ~ e.msg);
        }
        
        return plugins;
    }
}

// Helper functions

private Dependency[] parseDependencies(string content)
{
    Dependency[] deps;
    
    // Match: "org.typelevel" %% "cats-core" % "2.9.0"
    auto pattern = regex(`"([^"]+)"\s*%%?\s*"([^"]+)"\s*%\s*"([^"]+)"`);
    
    foreach (match; matchAll(content, pattern))
    {
        Dependency dep;
        dep.organization = match[1];
        dep.name = match[2];
        dep.version_ = match[3];
        deps ~= dep;
    }
    
    return deps;
}

private string[] parseResolvers(string content)
{
    string[] resolvers;
    
    // Match: resolvers += "Resolver Name" at "http://..."
    auto pattern = regex(`resolvers\s*\+=\s*"([^"]+)"\s*at\s*"([^"]+)"`);
    
    foreach (match; matchAll(content, pattern))
    {
        resolvers ~= match[2];
    }
    
    return resolvers;
}

