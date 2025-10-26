# CLI Package

The CLI package provides an event-driven rendering system for beautiful and informative build output in the terminal.

## Modules

- **events.d** - Strongly-typed build events
- **terminal.d** - Terminal control and capabilities detection
- **progress.d** - Lock-free progress tracking
- **stream.d** - Multi-stream output management
- **format.d** - Message formatting and styling
- **render.d** - Main rendering coordinator

## Usage

```d
import cli;

auto renderer = RendererFactory.create();
auto publisher = new SimpleEventPublisher();
publisher.subscribe(renderer);
publisher.publish(new BuildStartedEvent(...));
```

## Key Features

- Event-driven architecture for responsive UI
- Lock-free progress updates
- Multi-stream output (stdout, stderr, logs)
- ANSI color and formatting support
- Terminal capability detection
- Clean and informative build output

