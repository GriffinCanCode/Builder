module languages.compiled.rust.toolchain;

import std.process;
import std.string;
import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.conv;
import utils.logging.logger;

/// Rust toolchain information
struct Toolchain
{
    string name;
    string channel; // stable, beta, nightly
    string date;
    string target;
    bool isDefault;
    bool isInstalled;
}

/// Rust target triple information
struct TargetTriple
{
    string name;
    string arch;      // x86_64, aarch64, etc.
    string vendor;    // unknown, apple, pc, etc.
    string system;    // linux, darwin, windows, etc.
    string abi;       // gnu, musl, msvc, etc.
    bool isInstalled;
}

/// Rust component information
struct Component
{
    string name;
    bool isInstalled;
    bool isAvailable;
}

/// Rustup toolchain manager
class Rustup
{
    /// Check if rustup is available
    static bool isAvailable()
    {
        auto res = execute(["rustup", "--version"]);
        return res.status == 0;
    }
    
    /// Get rustup version
    static string getVersion()
    {
        auto res = execute(["rustup", "--version"]);
        if (res.status == 0)
        {
            auto lines = res.output.split("\n");
            if (!lines.empty)
                return lines[0].strip;
        }
        return "unknown";
    }
    
    /// Get default toolchain
    static string getDefaultToolchain()
    {
        auto res = execute(["rustup", "default"]);
        if (res.status == 0)
        {
            auto lines = res.output.split("\n");
            if (!lines.empty)
            {
                // Format: "stable-x86_64-unknown-linux-gnu (default)"
                auto line = lines[0].strip;
                auto parts = line.split(" ");
                if (!parts.empty)
                    return parts[0];
            }
        }
        return "stable";
    }
    
    /// List installed toolchains
    static Toolchain[] listToolchains()
    {
        Toolchain[] toolchains;
        
        auto res = execute(["rustup", "toolchain", "list"]);
        if (res.status != 0)
            return toolchains;
        
        foreach (line; res.output.split("\n"))
        {
            line = line.strip;
            if (line.empty)
                continue;
            
            Toolchain tc;
            tc.isInstalled = true;
            
            // Check if default
            if (line.endsWith("(default)"))
            {
                tc.isDefault = true;
                line = line[0 .. $ - 9].strip;
            }
            
            tc.name = line;
            
            // Parse channel
            if (line.startsWith("stable"))
                tc.channel = "stable";
            else if (line.startsWith("beta"))
                tc.channel = "beta";
            else if (line.startsWith("nightly"))
                tc.channel = "nightly";
            
            toolchains ~= tc;
        }
        
        return toolchains;
    }
    
    /// Install toolchain
    static bool installToolchain(string toolchain)
    {
        Logger.info("Installing Rust toolchain: " ~ toolchain);
        
        auto res = execute(["rustup", "toolchain", "install", toolchain]);
        
        if (res.status == 0)
        {
            Logger.info("Toolchain installed successfully");
            return true;
        }
        else
        {
            Logger.error("Failed to install toolchain: " ~ res.output);
            return false;
        }
    }
    
    /// List available targets for toolchain
    static TargetTriple[] listTargets(string toolchain = "")
    {
        TargetTriple[] targets;
        
        string[] cmd = ["rustup", "target", "list"];
        if (!toolchain.empty)
            cmd ~= ["--toolchain", toolchain];
        
        auto res = execute(cmd);
        if (res.status != 0)
            return targets;
        
        foreach (line; res.output.split("\n"))
        {
            line = line.strip;
            if (line.empty)
                continue;
            
            TargetTriple target;
            
            // Check if installed
            if (line.endsWith("(installed)"))
            {
                target.isInstalled = true;
                line = line[0 .. $ - 11].strip;
            }
            
            target.name = line;
            parseTargetTriple(target);
            
            targets ~= target;
        }
        
        return targets;
    }
    
    /// Install target for toolchain
    static bool installTarget(string target, string toolchain = "")
    {
        Logger.info("Installing Rust target: " ~ target);
        
        string[] cmd = ["rustup", "target", "add", target];
        if (!toolchain.empty)
            cmd ~= ["--toolchain", toolchain];
        
        auto res = execute(cmd);
        
        if (res.status == 0)
        {
            Logger.info("Target installed successfully");
            return true;
        }
        else
        {
            Logger.error("Failed to install target: " ~ res.output);
            return false;
        }
    }
    
    /// List components for toolchain
    static Component[] listComponents(string toolchain = "")
    {
        Component[] components;
        
        string[] cmd = ["rustup", "component", "list"];
        if (!toolchain.empty)
            cmd ~= ["--toolchain", toolchain];
        
        auto res = execute(cmd);
        if (res.status != 0)
            return components;
        
        foreach (line; res.output.split("\n"))
        {
            line = line.strip;
            if (line.empty)
                continue;
            
            Component comp;
            
            // Check status
            if (line.endsWith("(installed)"))
            {
                comp.isInstalled = true;
                comp.isAvailable = true;
                line = line[0 .. $ - 11].strip;
            }
            else
            {
                comp.isInstalled = false;
                comp.isAvailable = true;
            }
            
            comp.name = line;
            components ~= comp;
        }
        
        return components;
    }
    
    /// Install component
    static bool installComponent(string component, string toolchain = "")
    {
        Logger.info("Installing Rust component: " ~ component);
        
        string[] cmd = ["rustup", "component", "add", component];
        if (!toolchain.empty)
            cmd ~= ["--toolchain", toolchain];
        
        auto res = execute(cmd);
        
        if (res.status == 0)
        {
            Logger.info("Component installed successfully");
            return true;
        }
        else
        {
            Logger.error("Failed to install component: " ~ res.output);
            return false;
        }
    }
    
    /// Run command with specific toolchain
    static auto runWithToolchain(string toolchain, string[] command)
    {
        string[] cmd = ["rustup", "run", toolchain] ~ command;
        return execute(cmd);
    }
    
    private static void parseTargetTriple(ref TargetTriple target)
    {
        // Parse target triple: arch-vendor-system-abi
        // Example: x86_64-unknown-linux-gnu
        
        auto parts = target.name.split("-");
        if (parts.length >= 1)
            target.arch = parts[0];
        if (parts.length >= 2)
            target.vendor = parts[1];
        if (parts.length >= 3)
            target.system = parts[2];
        if (parts.length >= 4)
            target.abi = parts[3];
    }
}

/// Rust compiler interface
class RustCompiler
{
    /// Check if rustc is available
    static bool isAvailable()
    {
        auto res = execute(["rustc", "--version"]);
        return res.status == 0;
    }
    
    /// Get rustc version
    static string getVersion()
    {
        auto res = execute(["rustc", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Get rustc sysroot
    static string getSysroot()
    {
        auto res = execute(["rustc", "--print", "sysroot"]);
        if (res.status == 0)
            return res.output.strip;
        return "";
    }
    
    /// Get rustc target list
    static string[] getTargets()
    {
        auto res = execute(["rustc", "--print", "target-list"]);
        if (res.status != 0)
            return [];
        
        return res.output.split("\n").map!(s => s.strip).filter!(s => !s.empty).array;
    }
    
    /// Get rustc host target triple
    static string getHostTarget()
    {
        auto res = execute(["rustc", "-vV"]);
        if (res.status != 0)
            return "";
        
        foreach (line; res.output.split("\n"))
        {
            if (line.startsWith("host:"))
            {
                auto parts = line.split(":");
                if (parts.length >= 2)
                    return parts[1].strip;
            }
        }
        
        return "";
    }
    
    /// Get rustc LLVM version
    static string getLLVMVersion()
    {
        auto res = execute(["rustc", "--version", "--verbose"]);
        if (res.status != 0)
            return "";
        
        foreach (line; res.output.split("\n"))
        {
            if (line.startsWith("LLVM version:"))
            {
                auto parts = line.split(":");
                if (parts.length >= 2)
                    return parts[1].strip;
            }
        }
        
        return "";
    }
}

/// Cargo package manager interface
class Cargo
{
    /// Check if cargo is available
    static bool isAvailable()
    {
        auto res = execute(["cargo", "--version"]);
        return res.status == 0;
    }
    
    /// Get cargo version
    static string getVersion()
    {
        auto res = execute(["cargo", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Check if cargo command exists
    static bool hasCommand(string command)
    {
        auto res = execute(["cargo", command, "--help"]);
        return res.status == 0;
    }
    
    /// List installed cargo commands
    static string[] listCommands()
    {
        auto res = execute(["cargo", "--list"]);
        if (res.status != 0)
            return [];
        
        string[] commands;
        foreach (line; res.output.split("\n"))
        {
            line = line.strip;
            if (line.empty || !line.canFind(" "))
                continue;
            
            auto parts = line.split();
            if (!parts.empty)
                commands ~= parts[0];
        }
        
        return commands;
    }
    
    /// Clean cargo target directory
    static bool clean(string projectPath)
    {
        auto res = execute(["cargo", "clean"], null, Config.none, size_t.max, projectPath);
        return res.status == 0;
    }
    
    /// Update cargo dependencies
    static bool update(string projectPath)
    {
        auto res = execute(["cargo", "update"], null, Config.none, size_t.max, projectPath);
        return res.status == 0;
    }
}

/// Clippy linter interface
class Clippy
{
    /// Check if clippy is available
    static bool isAvailable()
    {
        auto res = execute(["cargo", "clippy", "--version"]);
        return res.status == 0;
    }
    
    /// Get clippy version
    static string getVersion()
    {
        auto res = execute(["cargo", "clippy", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Run clippy on project
    static auto run(string projectPath, string[] flags = [])
    {
        string[] cmd = ["cargo", "clippy"] ~ flags;
        return execute(cmd, null, Config.none, size_t.max, projectPath);
    }
}

/// Rustfmt formatter interface
class Rustfmt
{
    /// Check if rustfmt is available
    static bool isAvailable()
    {
        auto res = execute(["cargo", "fmt", "--version"]);
        return res.status == 0;
    }
    
    /// Get rustfmt version
    static string getVersion()
    {
        auto res = execute(["cargo", "fmt", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Format project
    static auto format(string projectPath, bool check = false)
    {
        string[] cmd = ["cargo", "fmt"];
        if (check)
            cmd ~= ["--check"];
        
        return execute(cmd, null, Config.none, size_t.max, projectPath);
    }
}


