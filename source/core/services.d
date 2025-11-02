module core.services;

import std.stdio;
import std.conv : to;
import core.graph.graph;
import core.execution.engine : ExecutionEngine;
import core.caching.cache;
import core.telemetry;
import core.telemetry.tracing;
import utils.logging.structured;
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
    private Tracer _tracer;
    private StructuredLogger _structuredLogger;
    
    /// Create services with production configuration
    this(WorkspaceConfig config, BuildOptions options)
    {
        this._config = config;
        this._renderMode = RenderMode.Auto;
        
        // Initialize observability (tracing and structured logging)
        this._initializeObservability();
        
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
            this._telemetryStorage = new TelemetryStorage(".builder-cache/telemetry", telemetryConfig);
            this._publisher.subscribe(this._telemetryCollector);
        }
        
        // Log initialization (after _structuredLogger is initialized)
        if (this._structuredLogger !is null)
        {
            string[string] fields;
            fields["cache_dir"] = options.cacheDir;
            fields["telemetry_enabled"] = this._telemetryEnabled.to!string;
            this._structuredLogger.info("Build services initialized", fields);
        }
    }
    
    /// Initialize observability infrastructure
    /// Tracing is ENABLED BY DEFAULT for comprehensive observability
    private void _initializeObservability()
    {
        import std.process : environment;
        import std.conv : to;
        
        // Initialize structured logger (always enabled)
        auto verbose = environment.get("BUILDER_VERBOSE", "0");
        auto minLevel = (verbose == "1" || verbose == "true") ? LogLevel.Debug : LogLevel.Info;
        this._structuredLogger = new StructuredLogger(minLevel);
        setStructuredLogger(this._structuredLogger);
        
        // Initialize distributed tracing (ENABLED BY DEFAULT)
        // Set BUILDER_TRACING_ENABLED=0 to disable
        auto tracingEnabled = environment.get("BUILDER_TRACING_ENABLED", "1");
        if (tracingEnabled != "0" && tracingEnabled != "false")
        {
            // Determine exporter type from environment
            auto exporterType = environment.get("BUILDER_TRACING_EXPORTER", "jaeger");
            auto outputFile = environment.get("BUILDER_TRACING_OUTPUT", ".builder-cache/traces/jaeger.json");
            
            SpanExporter exporter;
            if (exporterType == "console")
            {
                exporter = new ConsoleSpanExporter();
            }
            else  // Default to Jaeger
            {
                exporter = new JaegerSpanExporter(outputFile);
            }
            
            this._tracer = new Tracer(exporter);
            setTracer(this._tracer);
            
            string[string] fields;
            fields["exporter"] = exporterType;
            fields["output"] = (exporterType == "console") ? "console" : outputFile;
            this._structuredLogger.debug_("Distributed tracing enabled (default)", fields);
        }
        else
        {
            // Create disabled tracer (user explicitly disabled)
            this._tracer = new Tracer(null);
            this._tracer.setEnabled(false);
            setTracer(this._tracer);
            
            this._structuredLogger.debug_("Distributed tracing disabled by user");
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
    
    /// Create execution engine with modular service architecture
    /// 
    /// Parameters:
    ///   graph = Build graph to execute
    ///   maxParallelism = Maximum parallel tasks (0 = auto)
    ///   enableCheckpoints = Enable checkpoint/resume functionality
    ///   enableRetries = Enable automatic retry on failure
    ///   useWorkStealing = Use work-stealing scheduler (vs simple thread pool)
    ExecutionEngine createEngine(
        BuildGraph graph,
        size_t maxParallelism = 0,
        bool enableCheckpoints = true,
        bool enableRetries = true,
        bool useWorkStealing = true)
    {
        import core.execution.engine;
        import core.execution.services;
        
        // Create scheduling service
        auto schedulingMode = useWorkStealing ? SchedulingMode.WorkStealing : SchedulingMode.ThreadPool;
        auto scheduling = new SchedulingService(schedulingMode);
        
        // Create cache service
        auto cacheService = new CacheService(".builder-cache");
        
        // Create observability service
        auto observability = new ObservabilityService(_publisher, _tracer, _structuredLogger);
        
        // Create resilience service
        auto resilience = new ResilienceService(enableRetries, enableCheckpoints, ".");
        
        // Create handler registry
        auto handlers = new HandlerRegistry();
        handlers.initialize();
        
        // Create execution engine
        return new ExecutionEngine(
            graph,
            _config,
            scheduling,
            cacheService,
            observability,
            resilience,
            handlers
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


