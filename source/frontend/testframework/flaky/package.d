module frontend.testframework.flaky;

/// Flaky test detection and management
/// 
/// Provides sophisticated flaky test handling:
/// - Bayesian inference for flakiness probability
/// - Temporal pattern detection
/// - Automatic quarantine mechanism
/// - Adaptive retry logic

public import frontend.testframework.flaky.detector;
public import frontend.testframework.flaky.retry;

