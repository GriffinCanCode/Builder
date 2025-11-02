module languages.jvm.kotlin.config.test;

/// Testing framework selection
enum KotlinTestFramework
{
    Auto,       /// Auto-detect from dependencies
    KotlinTest, /// kotlin.test
    JUnit5,     /// JUnit 5
    JUnit4,     /// JUnit 4
    Kotest,     /// Kotest
    Spek,       /// Spek
    None        /// None - skip testing
}

/// Test execution configuration
struct TestConfig
{
    bool enabled = true;
    KotlinTestFramework framework = KotlinTestFramework.Auto;
    string[] testPaths;
    string[] includes;
    string[] excludes;
    bool parallel = false;
    int maxParallel = 0;
    bool failFast = false;
    bool verbose = false;
    string[] jvmArgs;
    string[] args;
    bool coverage = false;
    string coverageFormat = "html";
    int minCoverage = 0;
}

/// Kotlin testing configuration
struct KotlinTestConfig
{
    TestConfig test;
    bool runTests = true;
}

