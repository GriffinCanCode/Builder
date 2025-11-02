module testframework.flaky;

/// Flaky test detection and management
/// 
/// Provides sophisticated flaky test handling:
/// - Bayesian inference for flakiness probability
/// - Temporal pattern detection
/// - Automatic quarantine mechanism
/// - Adaptive retry logic

public import testframework.flaky.detector;
public import testframework.flaky.retry;

