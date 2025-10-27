# CLI Package

The CLI package provides an event-driven rendering system for beautiful and informative build output in the terminal, along with comprehensive command-line interface functionality.

## Modules

### Event-Driven Rendering
- **events.d** - Strongly-typed build events
- **terminal.d** - Terminal control and capabilities detection
- **progress.d** - Lock-free progress tracking
- **stream.d** - Multi-stream output management
- **format.d** - Message formatting and styling
- **render.d** - Main rendering coordinator

### Commands
- **commands/init.d** - Initialize Builderfile with auto-detection
- **commands/infer.d** - Preview auto-detected targets (dry-run)
- **commands/telemetry.d** - Build analytics and performance insights
- **commands/help.d** - Comprehensive help system for all commands

## Usage

```d
import cli;

auto renderer = RendererFactory.create();
auto publisher = new SimpleEventPublisher();
publisher.subscribe(renderer);
publisher.publish(new BuildStartedEvent(...));
```

## Key Features

### Rendering System
- Event-driven architecture for responsive UI
- Lock-free progress updates
- Multi-stream output (stdout, stderr, logs)
- ANSI color and formatting support
- Terminal capability detection
- Clean and informative build output

### Command System
- Comprehensive help documentation for all commands
- Auto-detection and inference capabilities
- Build analytics and telemetry
- Project initialization with smart detection
- Modular command structure for easy extension

