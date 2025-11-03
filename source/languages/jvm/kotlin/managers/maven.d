module languages.jvm.kotlin.managers.maven;

import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.process;
import std.regex;
import std.conv;
import infrastructure.utils.logging.logger;

/// Maven Kotlin project metadata
struct MavenKotlinMetadata
{
    string groupId;
    string artifactId;
    string version_;
    string packaging;
    
    string kotlinVersion;
    string[] dependencies;
    string[] plugins;
    
    bool usesKapt = false;
    bool usesKsp = false;
    
    /// Parse from pom.xml
    static MavenKotlinMetadata fromFile(string pomFile)
    {
        if (!exists(pomFile))
            throw new Exception("pom.xml not found at: " ~ pomFile);
        
        string content = readText(pomFile);
        return parsePomXML(content);
    }
    
    private static MavenKotlinMetadata parsePomXML(string content)
    {
        MavenKotlinMetadata meta;
        
        try
        {
            // Basic XML parsing with regex (simplified for speed)
            // For production, consider using a proper XML library
            
            // Parse groupId
            auto groupMatch = matchFirst(content, regex(`<groupId>([^<]+)</groupId>`));
            if (!groupMatch.empty)
                meta.groupId = groupMatch[1];
            
            // Parse artifactId
            auto artifactMatch = matchFirst(content, regex(`<artifactId>([^<]+)</artifactId>`));
            if (!artifactMatch.empty)
                meta.artifactId = artifactMatch[1];
            
            // Parse version
            auto versionMatch = matchFirst(content, regex(`<version>([^<]+)</version>`));
            if (!versionMatch.empty)
                meta.version_ = versionMatch[1];
            
            // Parse packaging
            auto packagingMatch = matchFirst(content, regex(`<packaging>([^<]+)</packaging>`));
            if (!packagingMatch.empty)
                meta.packaging = packagingMatch[1];
            
            // Parse Kotlin version from properties
            auto kotlinVerMatch = matchFirst(content, regex(`<kotlin\.version>([^<]+)</kotlin\.version>`));
            if (!kotlinVerMatch.empty)
                meta.kotlinVersion = kotlinVerMatch[1];
            
            // Parse plugins
            auto pluginsSection = matchFirst(content, regex(`<plugins>(.*?)</plugins>`, "s"));
            if (!pluginsSection.empty)
            {
                auto pluginPattern = regex(`<artifactId>([^<]+)</artifactId>`, "g");
                foreach (match; matchAll(pluginsSection[1], pluginPattern))
                {
                    string plugin = match[1];
                    meta.plugins ~= plugin;
                    
                    // Check for KAPT
                    if (plugin.canFind("kapt"))
                        meta.usesKapt = true;
                    
                    // Check for KSP
                    if (plugin.canFind("ksp") || plugin.canFind("symbol-processing"))
                        meta.usesKsp = true;
                }
            }
            
            // Parse dependencies
            auto depsSection = matchFirst(content, regex(`<dependencies>(.*?)</dependencies>`, "s"));
            if (!depsSection.empty)
            {
                auto depPattern = regex(`<groupId>([^<]+)</groupId>\s*<artifactId>([^<]+)</artifactId>\s*<version>([^<]*)</version>`, "sg");
                foreach (match; matchAll(depsSection[1], depPattern))
                {
                    string dep = match[1] ~ ":" ~ match[2];
                    if (!match[3].empty)
                        dep ~= ":" ~ match[3];
                    meta.dependencies ~= dep;
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse pom.xml: " ~ e.msg);
        }
        
        return meta;
    }
}

/// Maven operations for Kotlin projects
class MavenOps
{
    /// Execute Maven command
    static auto executeMaven(string[] args, string workingDir = ".")
    {
        return execute(["mvn"] ~ args, null, Config.none, size_t.max, workingDir);
    }
    
    /// Build Kotlin project
    static bool build(string projectDir, bool skipTests = false)
    {
        Logger.info("Building Kotlin project with Maven");
        
        string[] args = ["compile"];
        if (skipTests)
            args ~= ["-DskipTests"];
        
        auto result = executeMaven(args, projectDir);
        
        if (result.status != 0)
        {
            Logger.error("Maven build failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Package Kotlin project
    static bool package_(string projectDir, bool skipTests = false)
    {
        Logger.info("Packaging Kotlin project with Maven");
        
        string[] args = ["package"];
        if (skipTests)
            args ~= ["-DskipTests"];
        
        auto result = executeMaven(args, projectDir);
        
        if (result.status != 0)
        {
            Logger.error("Maven package failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Run Kotlin tests
    static bool test(string projectDir)
    {
        Logger.info("Running Kotlin tests with Maven");
        
        auto result = executeMaven(["test"], projectDir);
        
        if (result.status != 0)
        {
            Logger.error("Maven tests failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Clean build
    static bool clean(string projectDir)
    {
        Logger.info("Cleaning Maven project");
        
        auto result = executeMaven(["clean"], projectDir);
        
        return result.status == 0;
    }
    
    /// Install dependencies
    static bool installDependencies(string projectDir)
    {
        Logger.info("Installing Maven dependencies");
        
        auto result = executeMaven(["dependency:resolve"], projectDir);
        
        return result.status == 0;
    }
    
    /// Compile Kotlin sources
    static bool compileKotlin(string projectDir)
    {
        Logger.info("Compiling Kotlin sources with Maven");
        
        auto result = executeMaven(["kotlin:compile"], projectDir);
        
        if (result.status != 0)
        {
            Logger.error("Kotlin compilation failed: " ~ result.output);
            return false;
        }
        
        return true;
    }
    
    /// Get Maven version
    static string getVersion()
    {
        auto result = execute(["mvn", "--version"]);
        if (result.status == 0)
        {
            auto match = matchFirst(result.output, regex(`Apache Maven ([\d.]+)`));
            if (!match.empty)
                return match[1];
        }
        return "";
    }
}

