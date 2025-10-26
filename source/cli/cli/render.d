module cli.render;

import cli.events;
import cli.terminal;
import cli.progress;
import cli.stream;
import cli.format;
import std.datetime : Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.conv : to;

/// Main rendering coordinator
/// Subscribes to build events and orchestrates all CLI output

class Renderer : EventSubscriber
{
    private Terminal terminal;
    private Formatter formatter;
    private StreamMultiplexer streams;
    private StatusLine statusLine;
    private ProgressTracker* tracker;
    private ProgressBar progressBar;
    private RenderMode mode;
    private bool showProgress;
    private StopWatch buildTimer;
    
    this(RenderMode mode = RenderMode.Auto)
    {
        auto caps = Capabilities.detect();
        this.terminal = Terminal(caps, 8192); // 8KB buffer
        this.formatter = Formatter(caps);
        this.streams = new StreamMultiplexer(terminal, formatter);
        this.statusLine = new StatusLine(terminal, formatter);
        this.progressBar = ProgressBar(40);
        this.buildTimer = StopWatch(AutoStart.no);
        
        // Determine mode
        if (mode == RenderMode.Auto)
        {
            this.mode = caps.isInteractive ? RenderMode.Interactive : RenderMode.Plain;
        }
        else
        {
            this.mode = mode;
        }
        
        this.showProgress = (this.mode == RenderMode.Interactive) && 
                           caps.supportsProgressBar;
    }
    
    /// Handle build events
    void onEvent(BuildEvent event)
    {
        final switch (event.type)
        {
            case EventType.BuildStarted:
                handleBuildStarted(cast(BuildStartedEvent)event);
                break;
            case EventType.BuildCompleted:
                handleBuildCompleted(cast(BuildCompletedEvent)event);
                break;
            case EventType.BuildFailed:
                handleBuildFailed(cast(BuildFailedEvent)event);
                break;
            case EventType.TargetStarted:
                handleTargetStarted(cast(TargetStartedEvent)event);
                break;
            case EventType.TargetCompleted:
                handleTargetCompleted(cast(TargetCompletedEvent)event);
                break;
            case EventType.TargetFailed:
                handleTargetFailed(cast(TargetFailedEvent)event);
                break;
            case EventType.TargetCached:
                handleTargetCached(cast(TargetCachedEvent)event);
                break;
            case EventType.TargetProgress:
                handleTargetProgress(cast(TargetProgressEvent)event);
                break;
            case EventType.Message:
                handleMessage(cast(MessageEvent)event);
                break;
            case EventType.Warning:
                handleWarning(cast(MessageEvent)event);
                break;
            case EventType.Error:
                handleError(cast(MessageEvent)event);
                break;
            case EventType.Statistics:
                handleStatistics(cast(StatisticsEvent)event);
                break;
        }
    }
    
    /// Set progress tracker reference
    void setProgressTracker(ProgressTracker* tracker)
    {
        this.tracker = tracker;
    }
    
    /// Flush all pending output
    void flush()
    {
        if (showProgress)
            statusLine.clear();
        
        streams.flushAll();
        terminal.flush();
    }
    
    private void handleBuildStarted(BuildStartedEvent event)
    {
        buildTimer.reset();
        buildTimer.start();
        
        terminal.writeln();
        terminal.writeln(formatter.formatBuildStarted(
            event.totalTargets, event.maxParallelism));
        terminal.writeln();
        terminal.flush();
    }
    
    private void handleBuildCompleted(BuildCompletedEvent event)
    {
        buildTimer.stop();
        
        if (showProgress)
            statusLine.clear();
        
        terminal.writeln();
        terminal.writeln(formatter.formatBuildCompleted(
            event.built, event.cached, event.duration));
        terminal.writeln();
        terminal.flush();
    }
    
    private void handleBuildFailed(BuildFailedEvent event)
    {
        buildTimer.stop();
        
        if (showProgress)
            statusLine.clear();
        
        terminal.writeln();
        terminal.writeln(formatter.formatBuildFailed(
            event.failedCount, event.duration));
        terminal.writeln();
        terminal.flush();
    }
    
    private void handleTargetStarted(TargetStartedEvent event)
    {
        if (mode == RenderMode.Verbose)
        {
            writeLine(formatter.formatTargetStarted(
                event.targetId, event.index, event.total));
        }
        
        updateProgressStatus();
    }
    
    private void handleTargetCompleted(TargetCompletedEvent event)
    {
        if (mode != RenderMode.Quiet)
        {
            writeLine(formatter.formatTargetCompleted(
                event.targetId, event.duration));
        }
        
        updateProgressStatus();
    }
    
    private void handleTargetFailed(TargetFailedEvent event)
    {
        writeLine(formatter.formatTargetFailed(
            event.targetId, event.error));
        
        updateProgressStatus();
    }
    
    private void handleTargetCached(TargetCachedEvent event)
    {
        if (mode == RenderMode.Verbose)
        {
            writeLine(formatter.formatTargetCached(event.targetId));
        }
        
        updateProgressStatus();
    }
    
    private void handleTargetProgress(TargetProgressEvent event)
    {
        // Could be used for per-target progress bars in future
        updateProgressStatus();
    }
    
    private void handleMessage(MessageEvent event)
    {
        string msg;
        final switch (event.severity)
        {
            case Severity.Debug:
                msg = formatter.formatDebug(event.message);
                break;
            case Severity.Info:
                msg = formatter.formatInfo(event.message);
                break;
            case Severity.Warning:
                msg = formatter.formatWarning(event.message);
                break;
            case Severity.Error:
            case Severity.Critical:
                msg = formatter.formatError(event.message);
                break;
        }
        
        writeLine(msg);
    }
    
    private void handleWarning(MessageEvent event)
    {
        writeLine(formatter.formatWarning(event.message));
    }
    
    private void handleError(MessageEvent event)
    {
        writeLine(formatter.formatError(event.message));
    }
    
    private void handleStatistics(StatisticsEvent event)
    {
        if (mode == RenderMode.Quiet)
            return;
        
        terminal.writeln();
        terminal.writeln(formatter.formatCacheStats(event.cacheStats));
        terminal.writeln();
        terminal.writeln(formatter.formatBuildStats(event.buildStats));
        terminal.writeln();
        terminal.flush();
    }
    
    /// Update progress status line
    private void updateProgressStatus()
    {
        if (!showProgress || tracker is null)
            return;
        
        auto snap = tracker.snapshot();
        auto statusText = progressBar.renderComplete(snap);
        statusLine.update(statusText);
    }
    
    /// Write line (handling status line if needed)
    private void writeLine(string line)
    {
        if (showProgress)
        {
            statusLine.withClear(() {
                terminal.writeln(line);
                terminal.flush();
            });
        }
        else
        {
            terminal.writeln(line);
            terminal.flush();
        }
    }
}

/// Render mode configuration
enum RenderMode
{
    Auto,        // Detect based on terminal capabilities
    Interactive, // Full interactive with progress bars
    Plain,       // Simple text output
    Verbose,     // Detailed output
    Quiet        // Minimal output
}

/// Simple event publisher implementation
class SimpleEventPublisher : EventPublisher
{
    private EventSubscriber[] subscribers;
    
    void publish(BuildEvent event)
    {
        foreach (subscriber; subscribers)
            subscriber.onEvent(event);
    }
    
    void subscribe(EventSubscriber subscriber)
    {
        subscribers ~= subscriber;
    }
    
    void unsubscribe(EventSubscriber subscriber)
    {
        import std.algorithm : remove;
        import std.array : array;
        
        subscribers = subscribers.remove!(s => s is subscriber).array;
    }
}

/// Factory for creating renderers
struct RendererFactory
{
    /// Create renderer with default settings
    static Renderer create(RenderMode mode = RenderMode.Auto)
    {
        return new Renderer(mode);
    }
    
    /// Create renderer with event publisher
    static Renderer createWithPublisher(EventPublisher publisher, 
                                       RenderMode mode = RenderMode.Auto)
    {
        auto renderer = create(mode);
        publisher.subscribe(renderer);
        return renderer;
    }
}

