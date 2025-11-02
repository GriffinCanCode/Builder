#!/usr/bin/env python3
"""
Example plugin using the Builder Plugin SDK

This demonstrates how easy it is to create plugins with the SDK.
"""

from builder_plugin_sdk import Plugin, pre_hook, post_hook, success

# Create plugin instance
plugin = Plugin(
    name="example",
    version="1.0.0",
    author="Builder Team",
    description="Example plugin using SDK"
)

@pre_hook
def setup_environment(target, workspace):
    """Setup environment before build"""
    logs = [
        "Setting up build environment",
        f"Target: {target.name}",
        f"Language: {target.language}",
        f"Sources: {len(target.sources)} files"
    ]
    
    # Do some pre-build work
    logs.append("✓ Environment ready")
    
    return success(logs)

@post_hook
def cleanup_and_report(target, workspace, outputs, build_success, duration_ms):
    """Cleanup and generate report after build"""
    logs = [
        "Post-build processing",
        f"Status: {'Success' if build_success else 'Failed'}",
        f"Duration: {duration_ms}ms"
    ]
    
    if outputs:
        logs.append(f"Generated {len(outputs)} artifacts:")
        for output in outputs[:5]:  # Show first 5
            logs.append(f"  - {output}")
    
    logs.append("✓ Post-build complete")
    
    return success(logs)

# Register handlers
plugin.register("build.pre_hook", setup_environment)
plugin.register("build.post_hook", cleanup_and_report)

if __name__ == "__main__":
    plugin.run()

