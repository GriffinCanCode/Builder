module infrastructure.migration.registry;

import std.string : toLower;
import infrastructure.migration.base;
import infrastructure.migration.systems;

/// Registry for build system migrators
/// Follows the same pattern as LanguageRegistry
class MigratorRegistry
{
    private IMigrator[string] migrators;
    private static MigratorRegistry instance;
    
    private this()
    {
        registerMigrators();
    }
    
    /// Get singleton instance
    static MigratorRegistry getInstance()
    {
        if (instance is null)
            instance = new MigratorRegistry();
        return instance;
    }
    
    /// Register a migrator
    void register(IMigrator migrator)
    {
        migrators[migrator.systemName().toLower()] = migrator;
    }
    
    /// Create migrator by name
    IMigrator create(string systemName)
    {
        auto key = systemName.toLower();
        if (key in migrators)
            return migrators[key];
        return null;
    }
    
    /// Check if system is supported
    bool isSupported(string systemName) const
    {
        auto key = systemName.toLower();
        return (key in migrators) !is null;
    }
    
    /// Get all available system names
    string[] availableSystems() const
    {
        import std.array : array;
        return migrators.keys.array;
    }
    
    /// Get all migrators
    IMigrator[] allMigrators()
    {
        import std.array : array;
        return migrators.values.array;
    }
    
    private void registerMigrators()
    {
        // Register all migrators
        register(new BazelMigrator());
        register(new CMakeMigrator());
        register(new MavenMigrator());
        register(new GradleMigrator());
        register(new MakeMigrator());
        register(new CargoMigrator());
        register(new NpmMigrator());
        register(new GoModuleMigrator());
        register(new DubMigrator());
        register(new SbtMigrator());
        register(new MesonMigrator());
    }
}

/// Convenience function to get registry
MigratorRegistry getMigratorRegistry()
{
    return MigratorRegistry.getInstance();
}

