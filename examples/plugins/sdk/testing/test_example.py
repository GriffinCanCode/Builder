#!/usr/bin/env python3
"""
Example plugin tests using the testing utilities
"""

import sys
from plugin_test_utils import PluginTester, TestTarget, TestWorkspace

def test_plugin_info():
    """Test plugin info endpoint"""
    tester = PluginTester("../builder-plugin-demo")
    
    # Test basic info
    info = tester.test_info()
    assert info["name"] == "demo"
    assert info["version"] == "1.0.0"
    assert "build.pre_hook" in info["capabilities"]
    assert "build.post_hook" in info["capabilities"]
    
    print("✓ Plugin info test passed")

def test_pre_hook():
    """Test pre-build hook"""
    tester = PluginTester("../builder-plugin-demo")
    
    # Create test target
    target = TestTarget(
        name="//test:app",
        language="python",
        sources=["src/main.py", "src/utils.py"]
    )
    
    workspace = TestWorkspace(root="/tmp/test")
    
    # Run pre-hook
    result = tester.test_pre_hook(target, workspace)
    
    # Verify success
    tester.assert_hook_success(result)
    tester.assert_hook_logs_contain(
        result,
        "Pre-build hook executing",
        "//test:app"
    )
    
    print("✓ Pre-hook test passed")

def test_post_hook():
    """Test post-build hook"""
    tester = PluginTester("../builder-plugin-demo")
    
    target = TestTarget(name="//test:app")
    workspace = TestWorkspace()
    
    # Test successful build
    result = tester.test_post_hook(
        target,
        workspace,
        outputs=["bin/app", "bin/lib.a"],
        success=True,
        duration_ms=2500
    )
    
    tester.assert_hook_success(result)
    tester.assert_hook_logs_contain(
        result,
        "Post-build hook executing",
        "succeeded",
        "2500ms"
    )
    
    print("✓ Post-hook test passed")

def test_failed_build():
    """Test post-hook with failed build"""
    tester = PluginTester("../builder-plugin-demo")
    
    target = TestTarget(name="//test:app")
    workspace = TestWorkspace()
    
    # Test failed build
    result = tester.test_post_hook(
        target,
        workspace,
        outputs=[],
        success=False,
        duration_ms=1500
    )
    
    # Should still succeed (hook handles failure gracefully)
    tester.assert_hook_success(result)
    tester.assert_hook_logs_contain(
        result,
        "failed"
    )
    
    print("✓ Failed build test passed")

def main():
    """Run all tests"""
    print("Running plugin tests...\n")
    
    try:
        test_plugin_info()
        test_pre_hook()
        test_post_hook()
        test_failed_build()
        
        print("\n✓ All tests passed!")
        return 0
        
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

