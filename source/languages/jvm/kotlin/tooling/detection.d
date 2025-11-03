module languages.jvm.kotlin.tooling.detection;

import std.process;
import std.string;
import std.algorithm;
import std.regex;
import infrastructure.utils.logging.logger;

/// Kotlin compiler and tool detection
class KotlinDetection
{
    /// Check if kotlinc is available
    static bool hasKotlinC()
    {
        auto result = execute(["kotlinc", "-version"]);
        return result.status == 0;
    }
    
    /// Check if kotlin-native is available
    static bool hasKotlinNative()
    {
        auto result = execute(["kotlinc-native", "-version"]);
        return result.status == 0;
    }
    
    /// Check if kotlin-js is available
    static bool hasKotlinJS()
    {
        auto result = execute(["kotlinc-js", "-version"]);
        return result.status == 0;
    }
    
    /// Check if Gradle is available
    static bool hasGradle()
    {
        auto result = execute(["gradle", "--version"]);
        return result.status == 0;
    }
    
    /// Check if Maven is available
    static bool hasMaven()
    {
        auto result = execute(["mvn", "--version"]);
        return result.status == 0;
    }
    
    /// Check if ktlint is available
    static bool hasKtLint()
    {
        auto result = execute(["ktlint", "--version"]);
        return result.status == 0;
    }
    
    /// Check if ktfmt is available
    static bool hasKtFmt()
    {
        auto result = execute(["ktfmt", "--version"]);
        return result.status == 0;
    }
    
    /// Check if detekt is available
    static bool hasDetekt()
    {
        auto result = execute(["detekt", "--version"]);
        return result.status == 0;
    }
    
    /// Get Kotlin compiler version
    static string getKotlinVersion()
    {
        auto result = execute(["kotlinc", "-version"]);
        if (result.status == 0)
        {
            auto match = matchFirst(result.output, regex(`(\d+\.\d+\.\d+)`));
            if (!match.empty)
                return match[1];
        }
        return "";
    }
    
    /// Get Gradle version
    static string getGradleVersion()
    {
        auto result = execute(["gradle", "--version"]);
        if (result.status == 0)
        {
            auto match = matchFirst(result.output, regex(`Gradle ([\d.]+)`));
            if (!match.empty)
                return match[1];
        }
        return "";
    }
    
    /// Get Maven version
    static string getMavenVersion()
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
    
    /// Get Java version (for JVM compilation)
    static string getJavaVersion()
    {
        auto result = execute(["java", "-version"]);
        if (result.status == 0)
        {
            auto match = matchFirst(result.output, regex(`version "([^"]+)"`));
            if (!match.empty)
                return match[1];
        }
        return "";
    }
    
    /// Check all available tools and log
    static void detectAll()
    {
        Logger.info("Detecting Kotlin tools...");
        
        if (hasKotlinC())
            Logger.info("  kotlinc: " ~ getKotlinVersion());
        else
            Logger.warning("  kotlinc: not found");
        
        if (hasKotlinNative())
            Logger.info("  kotlin-native: available");
        else
            Logger.debugLog("  kotlin-native: not found");
        
        if (hasKotlinJS())
            Logger.info("  kotlin-js: available");
        else
            Logger.debugLog("  kotlin-js: not found");
        
        if (hasGradle())
            Logger.info("  Gradle: " ~ getGradleVersion());
        else
            Logger.debugLog("  Gradle: not found");
        
        if (hasMaven())
            Logger.info("  Maven: " ~ getMavenVersion());
        else
            Logger.debugLog("  Maven: not found");
        
        if (hasKtLint())
            Logger.info("  ktlint: available");
        else
            Logger.debugLog("  ktlint: not found");
        
        if (hasDetekt())
            Logger.info("  detekt: available");
        else
            Logger.debugLog("  detekt: not found");
        
        Logger.info("  Java: " ~ getJavaVersion());
    }
}

