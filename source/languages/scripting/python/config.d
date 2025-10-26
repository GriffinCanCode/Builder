module languages.scripting.python.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Python build modes
enum PyBuildMode
{
    /// Script - single file or simple module (default)
    Script,
    /// Library - importable package
    Library,
    /// Package - distributable package with setup
    Package,
    /// Wheel - built wheel distribution
    Wheel,
    /// Application - standalone application
    Application
}

/// Package manager selection
enum PyPackageManager
{
    /// Auto-detect best available
    Auto,
    /// pip (standard)
    Pip,
    /// uv (ultra-fast, Rust-based)
    Uv,
    /// poetry (modern dependency management)
    Poetry,
    /// PDM (PEP 582 support)
    PDM,
    /// hatch (modern project management)
    Hatch,
    /// conda (scientific computing)
    Conda,
    /// pipenv (Pipfile-based)
    Pipenv,
    /// None - skip package management
    None
}

/// Type checker selection
enum PyTypeChecker
{
    /// Auto-detect best available
    Auto,
    /// mypy (standard, most comprehensive)
    Mypy,
    /// pyright (Microsoft, fast)
    Pyright,
    /// pytype (Google, inference-based)
    Pytype,
    /// pyre (Facebook, performance-focused)
    Pyre,
    /// None - skip type checking
    None
}

/// Code formatter selection
enum PyFormatter
{
    /// Auto-detect best available
    Auto,
    /// ruff format (fastest, Rust-based)
    Ruff,
    /// black (opinionated, popular)
    Black,
    /// blue (black fork, less strict)
    Blue,
    /// yapf (Google, configurable)
    Yapf,
    /// autopep8 (PEP 8 focused)
    Autopep8,
    /// None - skip formatting
    None
}

/// Linter selection
enum PyLinter
{
    /// Auto-detect best available
    Auto,
    /// ruff (fastest, comprehensive, Rust-based)
    Ruff,
    /// pylint (most comprehensive)
    Pylint,
    /// flake8 (combines multiple tools)
    Flake8,
    /// bandit (security-focused)
    Bandit,
    /// pyflakes (simple, fast)
    Pyflakes,
    /// None - skip linting
    None
}

/// Test runner selection
enum PyTestRunner
{
    /// Auto-detect from project
    Auto,
    /// pytest (most popular)
    Pytest,
    /// unittest (standard library)
    Unittest,
    /// nose2 (extends unittest)
    Nose2,
    /// tox (multi-environment)
    Tox,
    /// None - skip tests
    None
}

/// Python version specification
struct PyVersion
{
    /// Major version (e.g., 3)
    int major = 3;
    
    /// Minor version (e.g., 11)
    int minor = 11;
    
    /// Patch version (optional)
    int patch = 0;
    
    /// Specific interpreter path (overrides version)
    string interpreterPath;
    
    /// Use pyenv to manage versions
    bool usePyenv = false;
    
    /// Convert to string (e.g., "3.11")
    string toString() const
    {
        import std.conv : to;
        if (patch == 0)
            return major.to!string ~ "." ~ minor.to!string;
        return major.to!string ~ "." ~ minor.to!string ~ "." ~ patch.to!string;
    }
}

/// Virtual environment configuration
struct VirtualEnvConfig
{
    /// Use virtual environment
    bool enabled = true;
    
    /// Virtual environment directory
    string path = ".venv";
    
    /// Create if doesn't exist
    bool autoCreate = true;
    
    /// Virtual environment tool
    enum Tool
    {
        /// Auto-detect (venv, virtualenv, conda)
        Auto,
        /// venv (standard library)
        Venv,
        /// virtualenv (more features)
        Virtualenv,
        /// conda environment
        Conda,
        /// poetry environment
        Poetry,
        /// Use system Python (no venv)
        None
    }
    
    Tool tool = Tool.Auto;
    
    /// System site packages access
    bool systemSitePackages = false;
}

/// Type checking configuration
struct TypeCheckConfig
{
    /// Enable type checking
    bool enabled = false;
    
    /// Type checker to use
    PyTypeChecker checker = PyTypeChecker.Auto;
    
    /// Strict mode
    bool strict = false;
    
    /// Ignore missing imports
    bool ignoreMissingImports = false;
    
    /// Configuration file path (mypy.ini, pyproject.toml, etc.)
    string configFile;
    
    /// Warn on unused ignores
    bool warnUnusedIgnores = false;
    
    /// Disallow untyped defs
    bool disallowUntypedDefs = false;
    
    /// Disallow untyped calls
    bool disallowUntypedCalls = false;
    
    /// Check untyped defs
    bool checkUntypedDefs = false;
}

/// Testing configuration
struct TestConfig
{
    /// Test runner
    PyTestRunner runner = PyTestRunner.Auto;
    
    /// Test directory/pattern
    string[] testPaths;
    
    /// Verbose output
    bool verbose = false;
    
    /// Generate coverage
    bool coverage = false;
    
    /// Coverage output file
    string coverageFile = ".coverage";
    
    /// Coverage format (html, xml, json)
    string coverageFormat = "html";
    
    /// Minimum coverage percentage
    float minCoverage = 0.0;
    
    /// Fail if below minimum coverage
    bool failUnderCoverage = false;
    
    /// Run tests in parallel
    bool parallel = false;
    
    /// Number of parallel workers (0 = auto)
    int workers = 0;
}

/// Packaging configuration
struct PackageConfig
{
    /// Package build backend (setuptools, poetry, hatch, pdm, flit)
    string backend = "setuptools";
    
    /// Generate wheel
    bool buildWheel = false;
    
    /// Generate source distribution
    bool buildSdist = false;
    
    /// Output directory for distributions
    string distDir = "dist";
    
    /// Include data files
    bool includeData = true;
    
    /// pyproject.toml path
    string pyprojectPath;
    
    /// setup.py path
    string setupPath;
}

/// Python-specific build configuration
struct PyConfig
{
    /// Build mode
    PyBuildMode mode = PyBuildMode.Script;
    
    /// Python version requirement
    PyVersion pythonVersion;
    
    /// Virtual environment configuration
    VirtualEnvConfig venv;
    
    /// Package manager
    PyPackageManager packageManager = PyPackageManager.Auto;
    
    /// Type checking configuration
    TypeCheckConfig typeCheck;
    
    /// Formatter
    PyFormatter formatter = PyFormatter.None;
    
    /// Linter
    PyLinter linter = PyLinter.None;
    
    /// Testing configuration
    TestConfig test;
    
    /// Packaging configuration
    PackageConfig packaging;
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Use editable install for development
    bool editableInstall = false;
    
    /// Dependency file paths
    string[] requirementsFiles;
    
    /// Extra dependency groups to install
    string[] extraDeps;
    
    /// Format code before build
    bool autoFormat = false;
    
    /// Lint code before build
    bool autoLint = false;
    
    /// Optimization level (0 = none, 1 = basic, 2 = full)
    int optimize = 0;
    
    /// Compile to bytecode (.pyc)
    bool compileBytecode = false;
    
    /// Generate stubs (.pyi)
    bool generateStubs = false;
    
    /// Python path additions
    string[] pythonPath;
    
    /// Environment variables for build
    string[string] env;
    
    /// Parse from JSON
    static PyConfig fromJSON(JSONValue json)
    {
        PyConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "script": config.mode = PyBuildMode.Script; break;
                case "library": config.mode = PyBuildMode.Library; break;
                case "package": config.mode = PyBuildMode.Package; break;
                case "wheel": config.mode = PyBuildMode.Wheel; break;
                case "application": config.mode = PyBuildMode.Application; break;
                default: config.mode = PyBuildMode.Script; break;
            }
        }
        
        // Python version
        if ("pythonVersion" in json)
        {
            auto v = json["pythonVersion"];
            if (v.type == JSONType.string)
            {
                // Parse version string like "3.11"
                auto parts = v.str.split(".");
                if (parts.length >= 1) config.pythonVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.pythonVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.pythonVersion.patch = parts[2].to!int;
            }
            else if (v.type == JSONType.object)
            {
                if ("major" in v) config.pythonVersion.major = cast(int)v["major"].integer;
                if ("minor" in v) config.pythonVersion.minor = cast(int)v["minor"].integer;
                if ("patch" in v) config.pythonVersion.patch = cast(int)v["patch"].integer;
                if ("interpreterPath" in v) config.pythonVersion.interpreterPath = v["interpreterPath"].str;
                if ("usePyenv" in v) config.pythonVersion.usePyenv = v["usePyenv"].type == JSONType.true_;
            }
        }
        
        // Virtual environment
        if ("venv" in json)
        {
            auto v = json["venv"];
            if ("enabled" in v) config.venv.enabled = v["enabled"].type == JSONType.true_;
            if ("path" in v) config.venv.path = v["path"].str;
            if ("autoCreate" in v) config.venv.autoCreate = v["autoCreate"].type == JSONType.true_;
            if ("systemSitePackages" in v) config.venv.systemSitePackages = v["systemSitePackages"].type == JSONType.true_;
            
            if ("tool" in v)
            {
                string toolStr = v["tool"].str;
                switch (toolStr.toLower)
                {
                    case "auto": config.venv.tool = VirtualEnvConfig.Tool.Auto; break;
                    case "venv": config.venv.tool = VirtualEnvConfig.Tool.Venv; break;
                    case "virtualenv": config.venv.tool = VirtualEnvConfig.Tool.Virtualenv; break;
                    case "conda": config.venv.tool = VirtualEnvConfig.Tool.Conda; break;
                    case "poetry": config.venv.tool = VirtualEnvConfig.Tool.Poetry; break;
                    case "none": config.venv.tool = VirtualEnvConfig.Tool.None; break;
                    default: break;
                }
            }
        }
        
        // Package manager
        if ("packageManager" in json)
        {
            string pmStr = json["packageManager"].str;
            switch (pmStr.toLower)
            {
                case "auto": config.packageManager = PyPackageManager.Auto; break;
                case "pip": config.packageManager = PyPackageManager.Pip; break;
                case "uv": config.packageManager = PyPackageManager.Uv; break;
                case "poetry": config.packageManager = PyPackageManager.Poetry; break;
                case "pdm": config.packageManager = PyPackageManager.PDM; break;
                case "hatch": config.packageManager = PyPackageManager.Hatch; break;
                case "conda": config.packageManager = PyPackageManager.Conda; break;
                case "pipenv": config.packageManager = PyPackageManager.Pipenv; break;
                case "none": config.packageManager = PyPackageManager.None; break;
                default: config.packageManager = PyPackageManager.Auto; break;
            }
        }
        
        // Type checking
        if ("typeCheck" in json)
        {
            auto tc = json["typeCheck"];
            if ("enabled" in tc) config.typeCheck.enabled = tc["enabled"].type == JSONType.true_;
            if ("strict" in tc) config.typeCheck.strict = tc["strict"].type == JSONType.true_;
            if ("ignoreMissingImports" in tc) config.typeCheck.ignoreMissingImports = tc["ignoreMissingImports"].type == JSONType.true_;
            if ("configFile" in tc) config.typeCheck.configFile = tc["configFile"].str;
            if ("warnUnusedIgnores" in tc) config.typeCheck.warnUnusedIgnores = tc["warnUnusedIgnores"].type == JSONType.true_;
            if ("disallowUntypedDefs" in tc) config.typeCheck.disallowUntypedDefs = tc["disallowUntypedDefs"].type == JSONType.true_;
            if ("disallowUntypedCalls" in tc) config.typeCheck.disallowUntypedCalls = tc["disallowUntypedCalls"].type == JSONType.true_;
            if ("checkUntypedDefs" in tc) config.typeCheck.checkUntypedDefs = tc["checkUntypedDefs"].type == JSONType.true_;
            
            if ("checker" in tc)
            {
                string checkerStr = tc["checker"].str;
                switch (checkerStr.toLower)
                {
                    case "auto": config.typeCheck.checker = PyTypeChecker.Auto; break;
                    case "mypy": config.typeCheck.checker = PyTypeChecker.Mypy; break;
                    case "pyright": config.typeCheck.checker = PyTypeChecker.Pyright; break;
                    case "pytype": config.typeCheck.checker = PyTypeChecker.Pytype; break;
                    case "pyre": config.typeCheck.checker = PyTypeChecker.Pyre; break;
                    case "none": config.typeCheck.checker = PyTypeChecker.None; break;
                    default: break;
                }
            }
        }
        
        // Formatter
        if ("formatter" in json)
        {
            string fmtStr = json["formatter"].str;
            switch (fmtStr.toLower)
            {
                case "auto": config.formatter = PyFormatter.Auto; break;
                case "ruff": config.formatter = PyFormatter.Ruff; break;
                case "black": config.formatter = PyFormatter.Black; break;
                case "blue": config.formatter = PyFormatter.Blue; break;
                case "yapf": config.formatter = PyFormatter.Yapf; break;
                case "autopep8": config.formatter = PyFormatter.Autopep8; break;
                case "none": config.formatter = PyFormatter.None; break;
                default: break;
            }
        }
        
        // Linter
        if ("linter" in json)
        {
            string lintStr = json["linter"].str;
            switch (lintStr.toLower)
            {
                case "auto": config.linter = PyLinter.Auto; break;
                case "ruff": config.linter = PyLinter.Ruff; break;
                case "pylint": config.linter = PyLinter.Pylint; break;
                case "flake8": config.linter = PyLinter.Flake8; break;
                case "bandit": config.linter = PyLinter.Bandit; break;
                case "pyflakes": config.linter = PyLinter.Pyflakes; break;
                case "none": config.linter = PyLinter.None; break;
                default: break;
            }
        }
        
        // Testing
        if ("test" in json)
        {
            auto t = json["test"];
            if ("verbose" in t) config.test.verbose = t["verbose"].type == JSONType.true_;
            if ("coverage" in t) config.test.coverage = t["coverage"].type == JSONType.true_;
            if ("coverageFile" in t) config.test.coverageFile = t["coverageFile"].str;
            if ("coverageFormat" in t) config.test.coverageFormat = t["coverageFormat"].str;
            if ("minCoverage" in t) config.test.minCoverage = cast(float)t["minCoverage"].floating;
            if ("failUnderCoverage" in t) config.test.failUnderCoverage = t["failUnderCoverage"].type == JSONType.true_;
            if ("parallel" in t) config.test.parallel = t["parallel"].type == JSONType.true_;
            if ("workers" in t) config.test.workers = cast(int)t["workers"].integer;
            
            if ("testPaths" in t)
                config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            
            if ("runner" in t)
            {
                string runnerStr = t["runner"].str;
                switch (runnerStr.toLower)
                {
                    case "auto": config.test.runner = PyTestRunner.Auto; break;
                    case "pytest": config.test.runner = PyTestRunner.Pytest; break;
                    case "unittest": config.test.runner = PyTestRunner.Unittest; break;
                    case "nose2": config.test.runner = PyTestRunner.Nose2; break;
                    case "tox": config.test.runner = PyTestRunner.Tox; break;
                    case "none": config.test.runner = PyTestRunner.None; break;
                    default: break;
                }
            }
        }
        
        // Packaging
        if ("package" in json)
        {
            auto p = json["package"];
            if ("backend" in p) config.packaging.backend = p["backend"].str;
            if ("buildWheel" in p) config.packaging.buildWheel = p["buildWheel"].type == JSONType.true_;
            if ("buildSdist" in p) config.packaging.buildSdist = p["buildSdist"].type == JSONType.true_;
            if ("distDir" in p) config.packaging.distDir = p["distDir"].str;
            if ("includeData" in p) config.packaging.includeData = p["includeData"].type == JSONType.true_;
            if ("pyprojectPath" in p) config.packaging.pyprojectPath = p["pyprojectPath"].str;
            if ("setupPath" in p) config.packaging.setupPath = p["setupPath"].str;
        }
        
        // Booleans
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("editableInstall" in json) config.editableInstall = json["editableInstall"].type == JSONType.true_;
        if ("autoFormat" in json) config.autoFormat = json["autoFormat"].type == JSONType.true_;
        if ("autoLint" in json) config.autoLint = json["autoLint"].type == JSONType.true_;
        if ("compileBytecode" in json) config.compileBytecode = json["compileBytecode"].type == JSONType.true_;
        if ("generateStubs" in json) config.generateStubs = json["generateStubs"].type == JSONType.true_;
        
        // Integers
        if ("optimize" in json) config.optimize = cast(int)json["optimize"].integer;
        
        // Arrays
        if ("requirementsFiles" in json)
            config.requirementsFiles = json["requirementsFiles"].array.map!(e => e.str).array;
        if ("extraDeps" in json)
            config.extraDeps = json["extraDeps"].array.map!(e => e.str).array;
        if ("pythonPath" in json)
            config.pythonPath = json["pythonPath"].array.map!(e => e.str).array;
        
        // Environment
        if ("env" in json)
        {
            foreach (string key, value; json["env"].object)
            {
                config.env[key] = value.str;
            }
        }
        
        return config;
    }
}

/// Python build result
struct PyBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Type check warnings
    string[] typeWarnings;
    bool hadTypeErrors;
    
    /// Lint warnings
    string[] lintWarnings;
    
    /// Format issues
    string[] formatIssues;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
}

