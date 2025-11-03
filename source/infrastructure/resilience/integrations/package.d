module infrastructure.resilience.integrations;

/// Resilience Integration Wrappers
/// 
/// Pre-built wrappers for common transport and execution layers.
/// These wrappers integrate circuit breakers and rate limiting
/// at the highest levels for proper cascading behavior.
/// 
/// ## Available Integrations
/// 
/// - **cache** - Remote cache HTTP transport wrapper
/// - **protocol** - Distributed protocol transport wrapper
/// - **executor** - Remote executor wrapper
/// 
/// ## Usage
/// 
/// ### Remote Cache
/// 
/// ```d
/// import infrastructure.resilience.integrations;
/// 
/// auto config = RemoteCacheConfig("http://cache.example.com", ...);
/// auto resilience = new ResilienceService();
/// 
/// // Wrap transport with resilience
/// auto transport = new ResilientCacheTransport(config, resilience);
/// 
/// // Use as normal - resilience is transparent
/// auto result = transport.get(contentHash);
/// ```
/// 
/// ### Distributed Protocol
/// 
/// ```d
/// // Create resilient transport
/// auto transportResult = ResilientTransportFactory.create(
///     "http://worker:9000",
///     resilience
/// );
/// 
/// auto transport = transportResult.unwrap();
/// transport.sendHeartBeat(workerId, heartbeat);
/// ```
/// 
/// ### Remote Executor
/// 
/// ```d
/// auto executor = new RemoteExecutor(...);
/// auto resilientExecutor = new ResilientRemoteExecutor(
///     executor,
///     coordinatorUrl,
///     resilience
/// );
/// 
/// // Execute with automatic circuit breaking and rate limiting
/// auto result = resilientExecutor.execute(actionId, spec, command, workDir);
/// ```

public import infrastructure.resilience.integrations.cache;
public import infrastructure.resilience.integrations.protocol;
public import infrastructure.resilience.integrations.executor;

