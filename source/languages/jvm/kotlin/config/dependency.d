module languages.jvm.kotlin.config.dependency;

import std.json;

/// Gradle configuration
struct GradleConfig
{
    bool autoInstall = true;
    bool clean = false;
    bool skipTests = false;
    bool offline = false;
    bool refreshDependencies = false;
    string[] tasks;
    string buildType;
    bool daemon = true;
    bool parallel = true;
    bool configureonDemand = false;
    string gradleVersion;
    string wrapperUrl;
    bool buildCache = true;
    bool configCache = false;
    int maxWorkers = 0;
    string gradleHome;
    string[] jvmArgs;
    string[] args;
}

/// Maven configuration  
struct MavenConfig
{
    bool autoInstall = true;
    bool clean = false;
    bool skipTests = false;
    bool offline = false;
    bool updateSnapshots = false;
    string[] goals;
    string[] profiles;
    bool batch = false;
    bool showVersion = false;
    string settingsFile;
    string toolchainsFile;
    int threads = 1;
    string mavenHome;
    string localRepository;
    string[] args;
}

/// Dependency specification
struct KotlinDependency
{
    string group;
    string artifact;
    string version_;
    string scope = "implementation";
    bool optional = false;
    string[] exclusions;
}

/// Kotlin dependency configuration
struct KotlinDependencyConfig
{
    GradleConfig gradle;
    MavenConfig maven;
    KotlinDependency[] dependencies;
    bool autoInstall = true;
    bool resolveTransitive = true;
    string[] repositories;
}

