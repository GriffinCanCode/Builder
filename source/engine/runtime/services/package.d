module engine.runtime.services;

/// Service Container Module
/// Dependency injection and service lifecycle management
/// 
/// This module provides a centralized service container for managing
/// the lifecycle and wiring of core build system components.

public import engine.runtime.services.services;
public import engine.runtime.services.scheduling : ISchedulingService, SchedulingService, SchedulingMode;
public import engine.runtime.services.cache : ICacheService, CacheService;
public import engine.runtime.services.observability : IObservabilityService, ObservabilityService;
public import engine.runtime.services.resilience : IResilienceService, ResilienceService;
public import engine.runtime.services.registry : IHandlerRegistry, HandlerRegistry;

