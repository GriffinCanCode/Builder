module core.services;

import std.stdio;
import core.graph.graph;
import core.execution.executor;
import core.caching.cache;
import core.telemetry;
import config.schema.schema;
import config.parsing.parser;
import analysis.inference.analyzer;
import cli.events.events;
import cli.display.render;
import errors;

/// Service container for dependency injection
/// Manages the lifecycle and wiring of core build system components
/// 
/// Design Pattern: Service Locator + Dependency Injection
/// - Centralizes service creation and configuration
/// - Enables testing with mock implementations
/// - Reduces coupling between command handlers and concrete types
final class BuildServices
{
    private WorkspaceConfig _config;
    private DependencyAnalyzer _analyzer;
    private BuildCache _cache;
    private EventPublisher _publisher;
    private Renderer _renderer;
    private TelemetryCollector _telemetryCollector;
    private TelemetryStorage _telemetryStorage;
    private RenderMode _renderMode;
    private bool _telemetryEnabled;
    
    /// Create services with production configuration
    this(WorkspaceConfig config, BuildOptions options)
    {
        this._config = config;
        this._renderMode = RenderMode.Auto;
        
        // Initialize cache
        auto cacheConfig = CacheConfig.fromEnvironment();
        this._cache = new BuildCache(options.cacheDir, cacheConfig);
        
        // Initialize analyzer
        this._analyzer = new DependencyAnalyzer(config);
        
        // Initialize event system
        this._publisher = new SimpleEventPublisher();
        
        // Initialize telemetry
        auto telemetryConfig = TelemetryConfig.fromEnvironment();
        this._telemetryEnabled = telemetryConfig.enabled;
        if (this._telemetryEnabled)
        {
            this._telemetryCollector = new TelemetryCollector();
            this._telemetryStorage = new TelemetryStorage(".builder-telemetry", telemetryConfig);
            this._publisher.subscribe(this._telemetryCollector);
        }
    }
    
    /// Create services with explicit dependencies (for testing)
    this(
        WorkspaceConfig config,
        DependencyAnalyzer analyzer,
        BuildCache cache,
        EventPublisher publisher,
        Renderer renderer = null)
    {
        this._config = config;
        this._analyzer = analyzer;
        this._cache = cache;
        this._publisher = publisher;
        this._renderer = renderer;
        this._telemetryEnabled = false;
    }
    
    /// Get workspace configuration
    @property WorkspaceConfig config() { return _config; }
    
    /// Get dependency analyzer
    @property DependencyAnalyzer analyzer() { return _analyzer; }
    
    /// Get build cache
    @property BuildCache cache() { return _cache; }
    
    /// Get event publisher
    @property EventPublisher publisher() { return _publisher; }
    
    /// Get telemetry collector (may be null if disabled)
    @property TelemetryCollector telemetryCollector() { return _telemetryCollector; }
    
    /// Get telemetry storage (may be null if disabled)
    @property TelemetryStorage telemetryStorage() { return _telemetryStorage; }
    
    /// Check if telemetry is enabled
    @property bool telemetryEnabled() { return _telemetryEnabled; }
    
    /// Set render mode for UI
    void setRenderMode(RenderMode mode)
    {
        this._renderMode = mode;
        // Recreate renderer if it exists
        if (this._renderer !is null)
        {
            this._renderer = RendererFactory.createWithPublisher(_publisher, mode);
        }
    }
    
    /// Get or create renderer
    Renderer getRenderer()
    {
        if (this._renderer is null)
        {
            this._renderer = RendererFactory.createWithPublisher(_publisher, _renderMode);
        }
        return this._renderer;
    }
    
    /// Create a build executor
    /// 
    /// Parameters:
    ///   graph = Build graph to execute
    ///   maxParallelism = Maximum parallel tasks (0 = auto)
    ///   enableCheckpoints = Enable checkpoint/resume functionality
    ///   enableRetries = Enable automatic retry on failure
    BuildExecutor createExecutor(
        BuildGraph graph,
        size_t maxParallelism = 0,
        bool enableCheckpoints = true,
        bool enableRetries = true)
    {
        return new BuildExecutor(
            graph,
            _config,
            maxParallelism,
            _publisher,
            enableCheckpoints,
            enableRetries
        );
    }
    
    /// Persist telemetry data (if enabled)
    void saveTelemetry()
    {
        if (!_telemetryEnabled || _telemetryCollector is null || _telemetryStorage is null)
            return;
        
        auto sessionResult = _telemetryCollector.getSession();
        if (sessionResult.isOk)
        {
            auto session = sessionResult.unwrap();
            auto appendResult = _telemetryStorage.append(session);
            
            if (appendResult.isErr)
            {
                import utils.logging.logger;
                Logger.warning("Failed to persist telemetry: " ~ appendResult.unwrapErr().toString());
            }
        }
    }
    
    /// Flush any pending output
    void flush()
    {
        if (_renderer !is null)
        {
            _renderer.flush();
        }
    }
    
    /// Cleanup and shutdown services
    void shutdown()
    {
        // Flush any pending output
        flush();
        
        // Save telemetry
        saveTelemetry();
    }
}

/// Factory methods for creating services in different contexts
struct ServiceFactory
{
    /// Create services for production use
    static BuildServices createProduction(WorkspaceConfig config, BuildOptions options)
    {
        return new BuildServices(config, options);
    }
    
    /// Create services with workspace auto-detection
    static Result!(BuildServices, BuildError) createFromWorkspace(
        string workspaceRoot,
        BuildOptions options)
    {
        auto configResult = ConfigParser.parseWorkspace(workspaceRoot);
        if (configResult.isErr)
        {
            return Result!(BuildServices, BuildError).err(configResult.unwrapErr());
        }
        
        auto config = configResult.unwrap();
        auto services = new BuildServices(config, options);
        return Result!(BuildServices, BuildError).ok(services);
    }
    
    /// Create services for testing with mocks
    static BuildServices createForTesting(
        WorkspaceConfig config,
        DependencyAnalyzer analyzer,
        BuildCache cache,
        EventPublisher publisher)
    {
        return new BuildServices(config, analyzer, cache, publisher);
    }
}


