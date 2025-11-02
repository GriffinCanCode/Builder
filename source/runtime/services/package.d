module runtime.services;

/// Service Container Module
/// Dependency injection and service lifecycle management
/// 
/// This module provides a centralized service container for managing
/// the lifecycle and wiring of core build system components.

public import runtime.services.services;
public import runtime.services.scheduling : ISchedulingService, SchedulingService, SchedulingMode;
public import runtime.services.cache : ICacheService, CacheService;
public import runtime.services.observability : IObservabilityService, ObservabilityService;
public import runtime.services.resilience : IResilienceService, ResilienceService;
public import runtime.services.registry : IHandlerRegistry, HandlerRegistry;

