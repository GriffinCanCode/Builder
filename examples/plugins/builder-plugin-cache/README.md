# Builder Cache Plugin

Intelligent cache warming and optimization for Builder builds.

## Features

- **Predictive Cache Warming**: Pre-fetches dependencies based on build patterns
- **Dependency Graph Analysis**: Understands your project's dependency structure
- **Cache Optimization**: Automatically evicts low-value cache entries
- **Access Pattern Learning**: Improves predictions over time

## Build

```bash
dub build --build=release
```

## Install

```bash
cp builder-plugin-cache /usr/local/bin/
# Or via Homebrew:
brew install builder-plugin-cache
```

## Test

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}' | ./builder-plugin-cache
```

## Usage

The cache plugin automatically activates during builds when installed. It:

1. **Pre-Build**: Analyzes targets and warms the cache
2. **Post-Build**: Records access patterns for future predictions

## Configuration

Add to your `Builderspace`:

```d
workspace("myproject") {
    plugins: [
        {
            name: "cache";
            config: {
                max_size_gb: 10;
                prefetch_depth: 2;
            };
        }
    ];
}
```

## Algorithm

The cache warming uses a predictive scoring algorithm:

```
score = (recency × 0.4) + (frequency × 0.4) + (size_efficiency × 0.2)
```

Where:
- **Recency**: How recently the item was accessed
- **Frequency**: How often the item is accessed
- **Size Efficiency**: Smaller items score higher

## License

MIT

