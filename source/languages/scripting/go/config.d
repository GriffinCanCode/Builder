module languages.scripting.go.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;

/// Go build modes - official Go build system modes
enum GoBuildMode
{
    /// Standard executable (default)
    Executable,
    /// Archive for use in C code
    CArchive,
    /// Shared library for use in C code
    CShared,
    /// Go plugin (deprecated but still used)
    Plugin,
    /// Position Independent Executable
    PIE,
    /// Shared library
    Shared,
    /// Standard library package
    Library
}

/// Go build constraints (formerly build tags)
struct BuildConstraints
{
    /// OS constraints (e.g., "linux", "darwin", "windows")
    string[] os;
    
    /// Architecture constraints (e.g., "amd64", "arm64")
    string[] arch;
    
    /// Custom tags
    string[] tags;
    
    /// CGO enabled/disabled
    bool? cgoEnabled;
    
    /// Build constraint expression (Go 1.17+ format)
    string expression;
    
    /// Generate build flags for go build command
    string[] toBuildFlags() const
    {
        string[] flags;
        
        foreach (tag; tags)
        {
            flags ~= "-tags";
            flags ~= tag;
        }
        
        return flags;
    }
}

/// Cross-compilation target
struct CrossTarget
{
    /// Target operating system
    string goos;
    
    /// Target architecture  
    string goarch;
    
    /// Target ARM variant (for arm/arm64)
    string goarm;
    
    /// Target MIPS variant
    string gomips;
    
    /// Target 386 float mode
    string go386;
    
    /// Target AMD64 microarchitecture level
    string goamd64;
    
    /// Generate environment variables for cross-compilation
    string[string] toEnv() const
    {
        string[string] env;
        
        if (!goos.empty) env["GOOS"] = goos;
        if (!goarch.empty) env["GOARCH"] = goarch;
        if (!goarm.empty) env["GOARM"] = goarm;
        if (!gomips.empty) env["GOMIPS"] = gomips;
        if (!go386.empty) env["GO386"] = go386;
        if (!goamd64.empty) env["GOAMD64"] = goamd64;
        
        return env;
    }
    
    /// Check if this is a cross-compilation target
    bool isCross() const
    {
        import std.process : environment;
        
        if (!goos.empty && goos != environment.get("GOOS", ""))
            return true;
        if (!goarch.empty && goarch != environment.get("GOARCH", ""))
            return true;
            
        return false;
    }
}

/// CGO configuration
struct CGoConfig
{
    /// Enable CGO
    bool enabled = false;
    
    /// C compiler flags
    string[] cflags;
    
    /// C++ compiler flags  
    string[] cxxflags;
    
    /// Linker flags
    string[] ldflags;
    
    /// Package config flags
    string[] pkgConfig;
    
    /// C compiler to use
    string cc;
    
    /// C++ compiler to use
    string cxx;
    
    /// Generate environment variables for CGO
    string[string] toEnv() const
    {
        string[string] env;
        
        env["CGO_ENABLED"] = enabled ? "1" : "0";
        
        if (!cflags.empty)
            env["CGO_CFLAGS"] = cflags.join(" ");
        if (!cxxflags.empty)
            env["CGO_CXXFLAGS"] = cxxflags.join(" ");
        if (!ldflags.empty)
            env["CGO_LDFLAGS"] = ldflags.join(" ");
        if (!pkgConfig.empty)
            env["PKG_CONFIG_PATH"] = pkgConfig.join(":");
        if (!cc.empty)
            env["CC"] = cc;
        if (!cxx.empty)
            env["CXX"] = cxx;
            
        return env;
    }
}

/// Go module mode
enum GoModMode
{
    /// Auto-detect from go.mod
    Auto,
    /// Enable module mode
    On,
    /// Disable module mode (GOPATH)
    Off,
    /// Read-only module mode
    Readonly,
    /// Vendor mode
    Vendor
}

/// Go testing configuration
struct GoTestConfig
{
    /// Run tests verbosely
    bool verbose = false;
    
    /// Generate coverage profile
    bool coverage = false;
    
    /// Coverage output file
    string coverProfile;
    
    /// Coverage mode (set, count, atomic)
    string coverMode = "set";
    
    /// Enable race detector
    bool race = false;
    
    /// Run benchmarks
    bool bench = false;
    
    /// Benchmark pattern
    string benchPattern;
    
    /// Benchmark time
    string benchTime;
    
    /// Run fuzzing
    bool fuzz = false;
    
    /// Fuzz target
    string fuzzTarget;
    
    /// Test timeout
    string timeout;
    
    /// Number of parallel tests
    int parallel = 0;
    
    /// Short test mode
    bool short_ = false;
    
    /// Generate test flags
    string[] toFlags() const
    {
        string[] flags;
        
        if (verbose) flags ~= "-v";
        if (coverage)
        {
            flags ~= "-cover";
            if (!coverProfile.empty)
            {
                flags ~= "-coverprofile";
                flags ~= coverProfile;
            }
            if (!coverMode.empty)
            {
                flags ~= "-covermode";
                flags ~= coverMode;
            }
        }
        if (race) flags ~= "-race";
        if (bench)
        {
            flags ~= "-bench";
            flags ~= benchPattern.empty ? "." : benchPattern;
            if (!benchTime.empty)
            {
                flags ~= "-benchtime";
                flags ~= benchTime;
            }
        }
        if (fuzz && !fuzzTarget.empty)
        {
            flags ~= "-fuzz";
            flags ~= fuzzTarget;
        }
        if (!timeout.empty)
        {
            flags ~= "-timeout";
            flags ~= timeout;
        }
        if (parallel > 0)
        {
            import std.conv : to;
            flags ~= "-parallel";
            flags ~= parallel.to!string;
        }
        if (short_) flags ~= "-short";
        
        return flags;
    }
}

/// Go-specific build configuration
struct GoConfig
{
    /// Build mode
    GoBuildMode mode = GoBuildMode.Executable;
    
    /// Module mode
    GoModMode modMode = GoModMode.Auto;
    
    /// Build constraints
    BuildConstraints constraints;
    
    /// Cross-compilation target
    CrossTarget cross;
    
    /// CGO configuration
    CGoConfig cgo;
    
    /// Test configuration
    GoTestConfig test;
    
    /// Compiler flags (passed to -gcflags)
    string[] gcflags;
    
    /// Linker flags (passed to -ldflags)
    string[] ldflags;
    
    /// Assembly flags (passed to -asmflags)
    string[] asmflags;
    
    /// C flags (passed to -gccgoflags)
    string[] gccgoflags;
    
    /// Build tags (legacy, use constraints instead)
    string[] buildTags;
    
    /// Trimpath - remove file system paths from binary
    bool trimpath = false;
    
    /// Work directory for build artifacts
    string workDir;
    
    /// Output directory
    string outDir;
    
    /// Module path override
    string modPath;
    
    /// Use vendor directory
    bool vendor = false;
    
    /// Module cache directory
    string modCacheDir;
    
    /// Install dependencies before build
    bool installDeps = false;
    
    /// Run go mod tidy before build
    bool modTidy = false;
    
    /// Run go generate before build
    bool generate = false;
    
    /// Tooling options
    bool runFmt = false;
    bool runVet = false;
    bool runLint = false;
    string linter = "golangci-lint"; // or "staticcheck", "golint"
    
    /// Parse from JSON
    static GoConfig fromJSON(JSONValue json)
    {
        GoConfig config;
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "executable": config.mode = GoBuildMode.Executable; break;
                case "c-archive": config.mode = GoBuildMode.CArchive; break;
                case "c-shared": config.mode = GoBuildMode.CShared; break;
                case "plugin": config.mode = GoBuildMode.Plugin; break;
                case "pie": config.mode = GoBuildMode.PIE; break;
                case "shared": config.mode = GoBuildMode.Shared; break;
                case "library": config.mode = GoBuildMode.Library; break;
                default: config.mode = GoBuildMode.Executable; break;
            }
        }
        
        if ("modMode" in json)
        {
            string modModeStr = json["modMode"].str;
            switch (modModeStr.toLower)
            {
                case "auto": config.modMode = GoModMode.Auto; break;
                case "on": config.modMode = GoModMode.On; break;
                case "off": config.modMode = GoModMode.Off; break;
                case "readonly": config.modMode = GoModMode.Readonly; break;
                case "vendor": config.modMode = GoModMode.Vendor; break;
                default: config.modMode = GoModMode.Auto; break;
            }
        }
        
        // Build constraints
        if ("constraints" in json)
        {
            auto c = json["constraints"];
            if ("os" in c)
                config.constraints.os = c["os"].array.map!(e => e.str).array;
            if ("arch" in c)
                config.constraints.arch = c["arch"].array.map!(e => e.str).array;
            if ("tags" in c)
                config.constraints.tags = c["tags"].array.map!(e => e.str).array;
            if ("cgoEnabled" in c)
                config.constraints.cgoEnabled = c["cgoEnabled"].type == JSONType.true_;
            if ("expression" in c)
                config.constraints.expression = c["expression"].str;
        }
        
        // Cross-compilation
        if ("cross" in json)
        {
            auto x = json["cross"];
            if ("goos" in x) config.cross.goos = x["goos"].str;
            if ("goarch" in x) config.cross.goarch = x["goarch"].str;
            if ("goarm" in x) config.cross.goarm = x["goarm"].str;
            if ("gomips" in x) config.cross.gomips = x["gomips"].str;
            if ("go386" in x) config.cross.go386 = x["go386"].str;
            if ("goamd64" in x) config.cross.goamd64 = x["goamd64"].str;
        }
        
        // CGO
        if ("cgo" in json)
        {
            auto cgo = json["cgo"];
            if ("enabled" in cgo)
                config.cgo.enabled = cgo["enabled"].type == JSONType.true_;
            if ("cflags" in cgo)
                config.cgo.cflags = cgo["cflags"].array.map!(e => e.str).array;
            if ("cxxflags" in cgo)
                config.cgo.cxxflags = cgo["cxxflags"].array.map!(e => e.str).array;
            if ("ldflags" in cgo)
                config.cgo.ldflags = cgo["ldflags"].array.map!(e => e.str).array;
            if ("pkgConfig" in cgo)
                config.cgo.pkgConfig = cgo["pkgConfig"].array.map!(e => e.str).array;
            if ("cc" in cgo)
                config.cgo.cc = cgo["cc"].str;
            if ("cxx" in cgo)
                config.cgo.cxx = cgo["cxx"].str;
        }
        
        // Testing
        if ("test" in json)
        {
            auto test = json["test"];
            if ("verbose" in test)
                config.test.verbose = test["verbose"].type == JSONType.true_;
            if ("coverage" in test)
                config.test.coverage = test["coverage"].type == JSONType.true_;
            if ("coverProfile" in test)
                config.test.coverProfile = test["coverProfile"].str;
            if ("coverMode" in test)
                config.test.coverMode = test["coverMode"].str;
            if ("race" in test)
                config.test.race = test["race"].type == JSONType.true_;
            if ("bench" in test)
                config.test.bench = test["bench"].type == JSONType.true_;
            if ("benchPattern" in test)
                config.test.benchPattern = test["benchPattern"].str;
            if ("benchTime" in test)
                config.test.benchTime = test["benchTime"].str;
            if ("fuzz" in test)
                config.test.fuzz = test["fuzz"].type == JSONType.true_;
            if ("fuzzTarget" in test)
                config.test.fuzzTarget = test["fuzzTarget"].str;
            if ("timeout" in test)
                config.test.timeout = test["timeout"].str;
            if ("parallel" in test && test["parallel"].type == JSONType.integer)
                config.test.parallel = cast(int)test["parallel"].integer;
            if ("short" in test)
                config.test.short_ = test["short"].type == JSONType.true_;
        }
        
        // Arrays
        if ("gcflags" in json)
            config.gcflags = json["gcflags"].array.map!(e => e.str).array;
        if ("ldflags" in json)
            config.ldflags = json["ldflags"].array.map!(e => e.str).array;
        if ("asmflags" in json)
            config.asmflags = json["asmflags"].array.map!(e => e.str).array;
        if ("gccgoflags" in json)
            config.gccgoflags = json["gccgoflags"].array.map!(e => e.str).array;
        if ("buildTags" in json)
            config.buildTags = json["buildTags"].array.map!(e => e.str).array;
        
        // Booleans
        if ("trimpath" in json)
            config.trimpath = json["trimpath"].type == JSONType.true_;
        if ("vendor" in json)
            config.vendor = json["vendor"].type == JSONType.true_;
        if ("installDeps" in json)
            config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("modTidy" in json)
            config.modTidy = json["modTidy"].type == JSONType.true_;
        if ("generate" in json)
            config.generate = json["generate"].type == JSONType.true_;
        if ("runFmt" in json)
            config.runFmt = json["runFmt"].type == JSONType.true_;
        if ("runVet" in json)
            config.runVet = json["runVet"].type == JSONType.true_;
        if ("runLint" in json)
            config.runLint = json["runLint"].type == JSONType.true_;
        
        // Strings
        if ("workDir" in json) config.workDir = json["workDir"].str;
        if ("outDir" in json) config.outDir = json["outDir"].str;
        if ("modPath" in json) config.modPath = json["modPath"].str;
        if ("modCacheDir" in json) config.modCacheDir = json["modCacheDir"].str;
        if ("linter" in json) config.linter = json["linter"].str;
        
        return config;
    }
}

/// Build result for Go compilation
struct GoBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Tool output (fmt, vet, lint)
    string[] toolWarnings;
    bool hadToolErrors;
}

