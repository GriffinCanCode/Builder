# Builder Plugin Testing Utilities

Tools for testing Builder plugins without requiring a full Builder installation.

## Features

- **PluginTester**: Test harness for plugin execution
- **MockPlugin**: Generate mock plugins for testing Builder integration
- **Test Helpers**: Assertions and utilities for common test patterns
- **Quick Test**: One-line smoke testing

## Installation

```bash
# Copy to your test directory
cp plugin_test_utils.py your_plugin/tests/
```

## Quick Start

```python
from plugin_test_utils import PluginTester

# Create tester
tester = PluginTester("./builder-plugin-myplugin")

# Test plugin info
info = tester.test_info()
assert info["name"] == "myplugin"

# Test pre-hook
result = tester.test_pre_hook()
tester.assert_hook_success(result)

# Test post-hook
result = tester.test_post_hook(
    outputs=["bin/app"],
    success=True,
    duration_ms=1000
)
tester.assert_hook_success(result)
```

## API Reference

### PluginTester

```python
tester = PluginTester(plugin_path, timeout=5)

# Test methods
info = tester.test_info()
result = tester.test_pre_hook(target, workspace)
result = tester.test_post_hook(target, workspace, outputs, success, duration_ms)
result = tester.test_artifact_process(artifacts, config)

# Assertions
tester.assert_info(name="myplugin", version="1.0.0")
tester.assert_hook_success(result)
tester.assert_hook_logs_contain(result, "pattern1", "pattern2")
```

### TestTarget

```python
from plugin_test_utils import TestTarget

target = TestTarget(
    name="//app:main",
    type="executable",
    language="python",
    sources=["src/main.py"],
    deps=["//lib:core"],
    config={"key": "value"}
)
```

### TestWorkspace

```python
from plugin_test_utils import TestWorkspace

workspace = TestWorkspace(
    root="/path/to/workspace",
    cache_dir=".builder-cache",
    builder_version="1.0.0",
    config={}
)
```

### MockPlugin

```python
from plugin_test_utils import MockPlugin

# Create mock plugin
mock = MockPlugin(name="test", version="1.0.0")
mock.to_executable("/tmp/mock-plugin")

# Use in tests
tester = PluginTester("/tmp/mock-plugin")
```

### Quick Test

```python
from plugin_test_utils import quick_test

# One-line smoke test
if quick_test("./builder-plugin-myplugin"):
    print("Plugin works!")
```

## Example Test Suite

```python
#!/usr/bin/env python3
from plugin_test_utils import PluginTester, TestTarget, TestWorkspace

def test_my_plugin():
    tester = PluginTester("./builder-plugin-myplugin")
    
    # Test info
    tester.assert_info(
        name="myplugin",
        version="1.0.0",
        capabilities=["build.pre_hook", "build.post_hook"]
    )
    
    # Test pre-hook
    target = TestTarget(
        name="//app:test",
        sources=["src/main.py"]
    )
    result = tester.test_pre_hook(target)
    tester.assert_hook_success(result)
    tester.assert_hook_logs_contain(result, "initialized")
    
    # Test post-hook with success
    result = tester.test_post_hook(
        target,
        outputs=["bin/app"],
        success=True,
        duration_ms=2000
    )
    tester.assert_hook_success(result)
    
    # Test post-hook with failure
    result = tester.test_post_hook(
        target,
        outputs=[],
        success=False,
        duration_ms=500
    )
    # Plugin should handle failure gracefully
    tester.assert_hook_success(result)
    
    print("✓ All tests passed")

if __name__ == "__main__":
    test_my_plugin()
```

## Running Tests

```bash
# Run test suite
python3 test_example.py

# Quick smoke test
python3 -c "from plugin_test_utils import quick_test; quick_test('./builder-plugin-demo')"
```

## CI Integration

### GitHub Actions

```yaml
- name: Test plugin
  run: |
    cd examples/plugins
    python3 sdk/testing/test_example.py
```

### GitLab CI

```yaml
test:
  script:
    - cd examples/plugins
    - python3 sdk/testing/test_example.py
```

## Tips

- **Timeout**: Increase timeout for slow plugins
- **Mock Plugin**: Use for testing Builder integration
- **Test Isolation**: Use unique workspace paths per test
- **Error Testing**: Test both success and failure paths
- **Log Validation**: Check logs contain expected messages

## License

MIT

