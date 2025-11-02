module core.testing;

/// Test execution and reporting framework
/// 
/// This package provides infrastructure for running and reporting tests
/// across all supported languages. It integrates with the existing
/// language handlers and build system.
/// 
/// NEW FEATURES:
/// - Test sharding for parallel execution
/// - Multi-level test result caching
/// - Bayesian flaky test detection
/// - Advanced test executor
/// - Test analytics and insights

public import core.testing.results;
public import core.testing.discovery;
public import core.testing.reporter;
public import core.testing.junit;
public import core.testing.config;
public import core.testing.sharding;
public import core.testing.caching;
public import core.testing.flaky;
public import core.testing.execution;
public import core.testing.analytics;

