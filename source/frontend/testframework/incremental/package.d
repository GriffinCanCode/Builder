module frontend.testframework.incremental;

/// Incremental Test Execution
/// 
/// Smart test selection based on code changes and dependency tracking.
/// Only runs tests affected by changes.
/// 
/// Usage:
///   ```d
///   auto depCache = new DependencyCache();
///   auto selector = new IncrementalTestSelector(depCache);
///   
///   // Select affected tests
///   auto testsToRun = selector.selectTests(
///       allTests,
///       changedFiles,
///       (file) => file.endsWith("_test.d")
///   );
///   ```

public import frontend.testframework.incremental.selector;

