# Builder Plugin SDK for Python

Simplifies creating Builder plugins with decorators and helpers.

## Installation

```bash
pip install builder-plugin-sdk
# Or copy builder_plugin_sdk.py to your plugin directory
```

## Quick Start

```python
#!/usr/bin/env python3
from builder_plugin_sdk import Plugin, pre_hook, post_hook, success

plugin = Plugin(
    name="myplugin",
    version="1.0.0",
    author="Your Name",
    description="My awesome plugin"
)

@pre_hook
def before_build(target, workspace):
    """Called before build starts"""
    logs = [
        f"Pre-build for target: {target.name}",
        f"Workspace: {workspace.root}"
    ]
    return success(logs)

@post_hook
def after_build(target, workspace, outputs, build_success, duration_ms):
    """Called after build completes"""
    logs = [
        f"Build {'succeeded' if build_success else 'failed'}",
        f"Duration: {duration_ms}ms",
        f"Outputs: {len(outputs)}"
    ]
    return success(logs)

# Register handlers
plugin.register("build.pre_hook", before_build)
plugin.register("build.post_hook", after_build)

if __name__ == "__main__":
    plugin.run()
```

## API Reference

### Plugin Class

```python
plugin = Plugin(
    name="myplugin",
    version="1.0.0",
    author="Your Name",
    description="Plugin description",
    homepage="https://github.com/you/plugin",
    license="MIT"
)
```

### Decorators

```python
@pre_hook
def my_pre_hook(target, workspace):
    # Called before build
    return success(["Hook executed"])

@post_hook
def my_post_hook(target, workspace, outputs, build_success, duration_ms):
    # Called after build
    return success(["Hook executed"])

@artifact_processor
def process_artifacts(artifacts, config):
    # Process build artifacts
    return success(["Processed artifacts"])
```

### Helper Functions

```python
# Create success result
success(["Log message"], artifacts=[], modified_target=None)

# Create failure result
failure(["Error message"])

# Create log messages
log("Message 1", "Message 2", "Message 3")
```

### Data Classes

```python
# Target information
target.name        # Target name
target.type        # Target type (executable, library, etc.)
target.language    # Language (python, go, etc.)
target.sources     # List of source files
target.deps        # List of dependencies
target.config      # Target configuration

# Workspace information
workspace.root             # Workspace root directory
workspace.cache_dir        # Cache directory
workspace.builder_version  # Builder version
workspace.config           # Workspace configuration
```

## Complete Example

```python
#!/usr/bin/env python3
from builder_plugin_sdk import Plugin, pre_hook, post_hook, success, failure
import os

plugin = Plugin(
    name="example",
    version="1.0.0",
    author="Example Author",
    description="Example plugin with full features"
)

@pre_hook
def validate_environment(target, workspace):
    """Validate build environment"""
    logs = ["Validating environment"]
    
    # Check for required tools
    required_tools = ["git", "make"]
    missing_tools = []
    
    for tool in required_tools:
        if os.system(f"which {tool} > /dev/null 2>&1") != 0:
            missing_tools.append(tool)
    
    if missing_tools:
        logs.append(f"Missing tools: {', '.join(missing_tools)}")
        return failure(logs)
    
    logs.append("✓ Environment validated")
    return success(logs)

@post_hook
def generate_report(target, workspace, outputs, build_success, duration_ms):
    """Generate build report"""
    logs = ["Generating build report"]
    
    report = {
        "target": target.name,
        "success": build_success,
        "duration_ms": duration_ms,
        "outputs": outputs
    }
    
    report_path = os.path.join(workspace.cache_dir, "build-report.json")
    
    import json
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    logs.append(f"Report saved: {report_path}")
    return success(logs)

plugin.register("build.pre_hook", validate_environment)
plugin.register("build.post_hook", generate_report)

if __name__ == "__main__":
    plugin.run()
```

## Testing

```bash
# Test plugin info
echo '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}' | python3 myplugin.py

# Test pre-hook
echo '{"jsonrpc":"2.0","id":2,"method":"build.pre_hook","params":{"target":{"name":"//app:main","type":"executable","language":"python","sources":[],"deps":[],"config":{}},"workspace":{"root":".","cache_dir":".builder-cache","builder_version":"1.0.0","config":{}}}}' | python3 myplugin.py
```

## License

MIT

