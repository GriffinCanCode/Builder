module frontend.cli;

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
///   input.d     - Interactive prompts & user input
///
/// Usage:
///   auto renderer = RendererFactory.create();
///   auto publisher = new SimpleEventPublisher();
///   publisher.subscribe(renderer);
///   publisher.publish(new BuildStartedEvent(...));

public import frontend.cli.events.events;
public import frontend.cli.control.terminal;
public import frontend.cli.output.progress;
public import frontend.cli.output.stream;
public import frontend.cli.display.format;
public import frontend.cli.display.render;
public import frontend.cli.input;

