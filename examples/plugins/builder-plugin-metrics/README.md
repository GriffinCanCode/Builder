# Builder Metrics Plugin

Advanced build metrics and analytics for Builder builds.

## Features

- **Real-time Metrics Collection**: Capture detailed build statistics
- **Trend Analysis**: Track build performance over time
- **Intelligent Insights**: Automatically detect regressions and improvements
- **Historical Data**: Persistent metrics storage and analysis
- **Performance Tracking**: CPU, memory, and cache efficiency metrics

## Build

```bash
go build -o builder-plugin-metrics
```

## Install

```bash
cp builder-plugin-metrics /usr/local/bin/
# Or via Homebrew:
brew install builder-plugin-metrics
```

## Test

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}' | ./builder-plugin-metrics
```

## Metrics Collected

- **Build Duration**: Total time for each build
- **Success Rate**: Percentage of successful builds
- **Cache Hit Rate**: Efficiency of caching
- **Resource Usage**: CPU and memory utilization
- **Parallelism**: Number of concurrent jobs
- **Source/Output Counts**: File statistics

## Insights Generated

The plugin automatically generates insights:

- **Trend Detection**: "Builds are 15% faster recently"
- **Regression Warnings**: "Builds are 20% slower recently"
- **Cache Efficiency**: "Cache hit rate: 75%"
- **Historical Context**: "Average build time: 2.5s"

## Storage

Metrics are stored in `.builder-cache/metrics/` as JSON files.

## License

MIT

