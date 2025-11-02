module testframework;

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

public import testframework.results;
public import testframework.discovery;
public import testframework.reporter;
public import testframework.junit;
public import testframework.config;
public import testframework.sharding;
public import testframework.caching;
public import testframework.flaky;
public import testframework.execution;
public import testframework.analytics;

