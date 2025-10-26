module languages.scripting.r.managers.environments;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.json;
import languages.scripting.r.core.config;
import languages.scripting.r.tooling.info;
import utils.logging.logger;

/// Environment management result
struct EnvResult
{
    bool success;
    string error;
    string envPath;
}

/// Initialize R environment
EnvResult initializeEnvironment(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    if (manager == REnvManager.None)
    {
        return EnvResult(true, "", "");
    }
    
    Logger.info("Initializing R environment with " ~ manager.to!string);
    
    final switch (manager)
    {
        case REnvManager.Auto:
            return EnvResult(false, "Failed to auto-detect environment manager", "");
            
        case REnvManager.Renv:
            return initRenv(workDir, rCmd, config);
            
        case REnvManager.Packrat:
            return initPackrat(workDir, rCmd, config);
            
        case REnvManager.None:
            return EnvResult(true, "", "");
    }
}

/// Initialize renv environment
private EnvResult initRenv(string workDir, string rCmd, const ref RConfig config)
{
    string renvDir = buildPath(workDir, "renv");
    string renvLock = buildPath(workDir, "renv.lock");
    
    // Check if already initialized
    if (exists(renvDir) && isDir(renvDir))
    {
        Logger.debug_("renv environment already exists at: " ~ renvDir);
        return EnvResult(true, "", renvDir);
    }
    
    // Initialize renv
    string initCode = `renv::init(bare=TRUE, restart=FALSE)`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", initCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to initialize renv: " ~ res.output, "");
    }
    
    Logger.info("Created renv environment at: " ~ renvDir);
    return EnvResult(true, "", renvDir);
}

/// Initialize packrat environment
private EnvResult initPackrat(string workDir, string rCmd, const ref RConfig config)
{
    string packratDir = buildPath(workDir, "packrat");
    
    // Check if already initialized
    if (exists(packratDir) && isDir(packratDir))
    {
        Logger.debug_("packrat environment already exists at: " ~ packratDir);
        return EnvResult(true, "", packratDir);
    }
    
    // Initialize packrat
    string initCode = `packrat::init()`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", initCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to initialize packrat: " ~ res.output, "");
    }
    
    Logger.info("Created packrat environment at: " ~ packratDir);
    return EnvResult(true, "", packratDir);
}

/// Restore environment from lockfile
EnvResult restoreEnvironment(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    if (manager == REnvManager.None)
    {
        return EnvResult(true, "", "");
    }
    
    Logger.info("Restoring R environment from lockfile");
    
    final switch (manager)
    {
        case REnvManager.Auto:
            return EnvResult(false, "Failed to auto-detect environment manager", "");
            
        case REnvManager.Renv:
            return restoreRenv(workDir, rCmd, config);
            
        case REnvManager.Packrat:
            return restorePackrat(workDir, rCmd, config);
            
        case REnvManager.None:
            return EnvResult(true, "", "");
    }
}

/// Restore renv environment
private EnvResult restoreRenv(string workDir, string rCmd, const ref RConfig config)
{
    string renvLock = buildPath(workDir, "renv.lock");
    
    if (!exists(renvLock))
    {
        return EnvResult(false, "renv.lock not found", "");
    }
    
    string restoreCode = `renv::restore(prompt=FALSE)`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", restoreCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to restore renv: " ~ res.output, "");
    }
    
    Logger.info("Restored renv environment from renv.lock");
    return EnvResult(true, "", buildPath(workDir, "renv"));
}

/// Restore packrat environment
private EnvResult restorePackrat(string workDir, string rCmd, const ref RConfig config)
{
    string packratLock = buildPath(workDir, "packrat", "packrat.lock");
    
    if (!exists(packratLock))
    {
        return EnvResult(false, "packrat.lock not found", "");
    }
    
    string restoreCode = `packrat::restore(prompt=FALSE)`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", restoreCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to restore packrat: " ~ res.output, "");
    }
    
    Logger.info("Restored packrat environment from packrat.lock");
    return EnvResult(true, "", buildPath(workDir, "packrat"));
}

/// Snapshot environment to lockfile
EnvResult snapshotEnvironment(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    if (manager == REnvManager.None)
    {
        return EnvResult(true, "", "");
    }
    
    Logger.info("Creating environment snapshot");
    
    final switch (manager)
    {
        case REnvManager.Auto:
            return EnvResult(false, "Failed to auto-detect environment manager", "");
            
        case REnvManager.Renv:
            return snapshotRenv(workDir, rCmd, config);
            
        case REnvManager.Packrat:
            return snapshotPackrat(workDir, rCmd, config);
            
        case REnvManager.None:
            return EnvResult(true, "", "");
    }
}

/// Snapshot renv environment
private EnvResult snapshotRenv(string workDir, string rCmd, const ref RConfig config)
{
    string snapshotCode = `renv::snapshot(prompt=FALSE)`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", snapshotCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to snapshot renv: " ~ res.output, "");
    }
    
    string lockPath = buildPath(workDir, "renv.lock");
    Logger.info("Created renv snapshot: " ~ lockPath);
    return EnvResult(true, "", lockPath);
}

/// Snapshot packrat environment
private EnvResult snapshotPackrat(string workDir, string rCmd, const ref RConfig config)
{
    string snapshotCode = `packrat::snapshot()`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", snapshotCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to snapshot packrat: " ~ res.output, "");
    }
    
    string lockPath = buildPath(workDir, "packrat", "packrat.lock");
    Logger.info("Created packrat snapshot: " ~ lockPath);
    return EnvResult(true, "", lockPath);
}

/// Clean environment (remove cached packages)
EnvResult cleanEnvironment(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    if (manager == REnvManager.None)
    {
        return EnvResult(true, "", "");
    }
    
    Logger.info("Cleaning R environment");
    
    final switch (manager)
    {
        case REnvManager.Auto:
            return EnvResult(false, "Failed to auto-detect environment manager", "");
            
        case REnvManager.Renv:
            return cleanRenv(workDir, rCmd, config);
            
        case REnvManager.Packrat:
            return cleanPackrat(workDir, rCmd, config);
            
        case REnvManager.None:
            return EnvResult(true, "", "");
    }
}

/// Clean renv environment
private EnvResult cleanRenv(string workDir, string rCmd, const ref RConfig config)
{
    string cleanCode = `renv::clean()`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", cleanCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to clean renv: " ~ res.output, "");
    }
    
    Logger.info("Cleaned renv environment");
    return EnvResult(true, "", "");
}

/// Clean packrat environment
private EnvResult cleanPackrat(string workDir, string rCmd, const ref RConfig config)
{
    string cleanCode = `packrat::clean()`;
    
    auto env = prepareEnvironment(config);
    auto res = execute([rCmd, "-e", cleanCode], env, Config.none, size_t.max, workDir);
    
    if (res.status != 0)
    {
        return EnvResult(false, "Failed to clean packrat: " ~ res.output, "");
    }
    
    Logger.info("Cleaned packrat environment");
    return EnvResult(true, "", "");
}

/// Get environment status
struct EnvStatus
{
    bool exists;
    bool hasLockfile;
    string lockfilePath;
    int packageCount;
    string[] outdatedPackages;
}

/// Get environment status
EnvStatus getEnvironmentStatus(
    REnvManager manager,
    string workDir,
    string rCmd
)
{
    EnvStatus status;
    
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    final switch (manager)
    {
        case REnvManager.Auto:
        case REnvManager.None:
            return status;
            
        case REnvManager.Renv:
            string renvDir = buildPath(workDir, "renv");
            string renvLock = buildPath(workDir, "renv.lock");
            
            status.exists = exists(renvDir) && isDir(renvDir);
            status.hasLockfile = exists(renvLock);
            if (status.hasLockfile)
                status.lockfilePath = renvLock;
            
            if (status.exists)
            {
                // Get package count
                string countCode = `cat(length(.packages(all.available=TRUE)))`;
                auto res = execute([rCmd, "-e", countCode]);
                if (res.status == 0)
                {
                    import std.conv : to;
                    try {
                        status.packageCount = res.output.strip().to!int;
                    } catch (Exception e) {}
                }
            }
            return status;
            
        case REnvManager.Packrat:
            string packratDir = buildPath(workDir, "packrat");
            string packratLock = buildPath(workDir, "packrat", "packrat.lock");
            
            status.exists = exists(packratDir) && isDir(packratDir);
            status.hasLockfile = exists(packratLock);
            if (status.hasLockfile)
                status.lockfilePath = packratLock;
            
            if (status.exists)
            {
                // Get package count
                string countCode = `cat(nrow(packrat:::lockInfo()$packages))`;
                auto res = execute([rCmd, "-e", countCode]);
                if (res.status == 0)
                {
                    import std.conv : to;
                    try {
                        status.packageCount = res.output.strip().to!int;
                    } catch (Exception e) {}
                }
            }
            return status;
    }
}

/// Activate environment for execution
string[] getEnvironmentActivationCommands(
    REnvManager manager,
    string workDir,
    const ref RConfig config
)
{
    string[] commands;
    
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(config.rExecutable);
    }
    
    final switch (manager)
    {
        case REnvManager.Auto:
        case REnvManager.None:
            return commands;
            
        case REnvManager.Renv:
            // renv activates automatically via .Rprofile
            // But we can ensure it's activated
            commands ~= `renv::activate()`;
            return commands;
            
        case REnvManager.Packrat:
            // packrat also activates via .Rprofile
            commands ~= `packrat::on()`;
            return commands;
    }
}

/// Prepare environment variables for R execution with environment isolation
private string[string] prepareEnvironment(const ref RConfig config)
{
    import std.process : environment;
    
    string[string] env;
    
    // Copy system environment
    foreach (key, value; environment.toAA())
        env[key] = value;
    
    // Add custom R environment variables
    foreach (key, value; config.rEnv)
        env[key] = value;
    
    // Add library paths
    if (!config.libPaths.empty)
    {
        env["R_LIBS_USER"] = config.libPaths.join(":");
    }
    
    return env;
}

/// Check if environment is in sync with lockfile
bool isEnvironmentInSync(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    final switch (manager)
    {
        case REnvManager.Auto:
        case REnvManager.None:
            return true;
            
        case REnvManager.Renv:
            string statusCode = `cat(renv::status()$synchronized)`;
            auto env = prepareEnvironment(config);
            auto res = execute([rCmd, "-e", statusCode], env, Config.none, size_t.max, workDir);
            if (res.status == 0)
            {
                return res.output.strip().toLower() == "true";
            }
            return false;
            
        case REnvManager.Packrat:
            // packrat doesn't have a simple sync check
            // Return true if lockfile exists
            return exists(buildPath(workDir, "packrat", "packrat.lock"));
    }
}

/// Update environment packages
EnvResult updateEnvironment(
    REnvManager manager,
    string workDir,
    string rCmd,
    const ref RConfig config
)
{
    if (manager == REnvManager.Auto)
    {
        manager = detectBestEnvManager(rCmd);
    }
    
    if (manager == REnvManager.None)
    {
        return EnvResult(true, "", "");
    }
    
    Logger.info("Updating R environment packages");
    
    final switch (manager)
    {
        case REnvManager.Auto:
            return EnvResult(false, "Failed to auto-detect environment manager", "");
            
        case REnvManager.Renv:
            string updateCode = `renv::update()`;
            auto env = prepareEnvironment(config);
            auto res = execute([rCmd, "-e", updateCode], env, Config.none, size_t.max, workDir);
            
            if (res.status != 0)
            {
                return EnvResult(false, "Failed to update renv: " ~ res.output, "");
            }
            
            Logger.info("Updated renv environment");
            return EnvResult(true, "", buildPath(workDir, "renv"));
            
        case REnvManager.Packrat:
            // packrat doesn't have a simple update command
            return EnvResult(false, "Update not supported for packrat", "");
            
        case REnvManager.None:
            return EnvResult(true, "", "");
    }
}

