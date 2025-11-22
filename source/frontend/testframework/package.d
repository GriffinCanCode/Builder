module frontend.testframework;

/// Test execution and reporting framework
/// 
/// This package provides infrastructure for running and reporting tests
/// across all supported languages. It integrates with the existing
/// language handlers and build system.
/// 
/// Features:
/// - Test sharding for parallel execution
/// - Multi-level test result caching
/// - Bayesian flaky test detection
/// - Advanced test executor
/// - Test analytics and insights

public import frontend.testframework.results;
public import frontend.testframework.discovery;
public import frontend.testframework.reporter;
public import frontend.testframework.junit;
public import frontend.testframework.config;
public import frontend.testframework.sharding;
public import frontend.testframework.caching;
public import frontend.testframework.flaky;
public import frontend.testframework.execution;
public import frontend.testframework.analytics;

