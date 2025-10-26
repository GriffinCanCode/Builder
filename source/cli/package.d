module cli;

/// CLI Experience Package
/// Event-driven rendering system for build output
/// 
/// Architecture:
///   events.d    - Strongly-typed build events
///   terminal.d  - Terminal control & capabilities
///   progress.d  - Lock-free progress tracking
///   stream.d    - Multi-stream output management
///   format.d    - Message formatting & styling
///   render.d    - Main rendering coordinator
///
/// Usage:
///   auto renderer = RendererFactory.create();
///   auto publisher = new SimpleEventPublisher();
///   publisher.subscribe(renderer);
///   publisher.publish(new BuildStartedEvent(...));

public import cli.events;
public import cli.terminal;
public import cli.progress;
public import cli.stream;
public import cli.format;
public import cli.render;

