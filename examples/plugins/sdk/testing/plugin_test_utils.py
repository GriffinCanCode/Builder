"""
Builder Plugin Testing Utilities

Provides helpers for testing Builder plugins without requiring
a full Builder installation.

Example usage:
    from plugin_test_utils import PluginTester
    
    tester = PluginTester("./builder-plugin-myplugin")
    
    # Test plugin info
    info = tester.test_info()
    assert info["name"] == "myplugin"
    
    # Test pre-hook
    result = tester.test_pre_hook(
        target_name="//app:main",
        sources=["src/main.py"]
    )
    assert result["success"] == True
"""

import json
import subprocess
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

@dataclass
class TestTarget:
    """Test target configuration"""
    name: str = "//test:target"
    type: str = "executable"
    language: str = "python"
    sources: List[str] = None
    deps: List[str] = None
    config: Dict = None
    
    def __post_init__(self):
        if self.sources is None:
            self.sources = ["src/main.py"]
        if self.deps is None:
            self.deps = []
        if self.config is None:
            self.config = {}
    
    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "type": self.type,
            "language": self.language,
            "sources": self.sources,
            "deps": self.deps,
            "config": self.config
        }

@dataclass
class TestWorkspace:
    """Test workspace configuration"""
    root: str = "/tmp/test-workspace"
    cache_dir: str = ".builder-cache"
    builder_version: str = "1.0.0"
    config: Dict = None
    
    def __post_init__(self):
        if self.config is None:
            self.config = {}
    
    def to_dict(self) -> Dict:
        return {
            "root": self.root,
            "cache_dir": self.cache_dir,
            "builder_version": self.builder_version,
            "config": self.config
        }

class PluginTester:
    """Test harness for Builder plugins"""
    
    def __init__(self, plugin_path: str, timeout: int = 5):
        self.plugin_path = plugin_path
        self.timeout = timeout
        self.request_id = 1
    
    def _send_request(self, method: str, params: Optional[Dict] = None) -> Dict:
        """Send JSON-RPC request to plugin"""
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method
        }
        
        if params:
            request["params"] = params
        
        self.request_id += 1
        
        # Send to plugin via stdin
        request_json = json.dumps(request) + "\n"
        
        try:
            result = subprocess.run(
                [self.plugin_path],
                input=request_json,
                capture_output=True,
                text=True,
                timeout=self.timeout
            )
            
            if result.returncode != 0:
                raise PluginTestError(
                    f"Plugin exited with code {result.returncode}\n"
                    f"stderr: {result.stderr}"
                )
            
            # Parse response
            response = json.loads(result.stdout.strip())
            
            # Check for errors
            if "error" in response:
                error = response["error"]
                raise PluginTestError(
                    f"Plugin returned error: {error['message']} "
                    f"(code: {error['code']})"
                )
            
            return response.get("result", {})
            
        except subprocess.TimeoutExpired:
            raise PluginTestError(f"Plugin timed out after {self.timeout} seconds")
        except json.JSONDecodeError as e:
            raise PluginTestError(f"Invalid JSON response: {e}\nOutput: {result.stdout}")
        except Exception as e:
            raise PluginTestError(f"Failed to execute plugin: {e}")
    
    def test_info(self) -> Dict:
        """Test plugin.info method"""
        return self._send_request("plugin.info")
    
    def test_pre_hook(
        self,
        target: Optional[TestTarget] = None,
        workspace: Optional[TestWorkspace] = None
    ) -> Dict:
        """Test build.pre_hook method"""
        if target is None:
            target = TestTarget()
        if workspace is None:
            workspace = TestWorkspace()
        
        params = {
            "target": target.to_dict(),
            "workspace": workspace.to_dict()
        }
        
        return self._send_request("build.pre_hook", params)
    
    def test_post_hook(
        self,
        target: Optional[TestTarget] = None,
        workspace: Optional[TestWorkspace] = None,
        outputs: Optional[List[str]] = None,
        success: bool = True,
        duration_ms: int = 1000
    ) -> Dict:
        """Test build.post_hook method"""
        if target is None:
            target = TestTarget()
        if workspace is None:
            workspace = TestWorkspace()
        if outputs is None:
            outputs = ["bin/app"]
        
        params = {
            "target": target.to_dict(),
            "workspace": workspace.to_dict(),
            "outputs": outputs,
            "success": success,
            "duration_ms": duration_ms
        }
        
        return self._send_request("build.post_hook", params)
    
    def test_artifact_process(
        self,
        artifacts: Optional[List[Dict]] = None,
        config: Optional[Dict] = None
    ) -> Dict:
        """Test artifact.process method"""
        if artifacts is None:
            artifacts = [
                {"path": "bin/app", "type": "executable"},
                {"path": "lib/libcore.a", "type": "static_library"}
            ]
        if config is None:
            config = {}
        
        params = {
            "artifacts": artifacts,
            "config": config
        }
        
        return self._send_request("artifact.process", params)
    
    def assert_info(
        self,
        name: Optional[str] = None,
        version: Optional[str] = None,
        capabilities: Optional[List[str]] = None
    ):
        """Assert plugin info matches expectations"""
        info = self.test_info()
        
        if name:
            assert info.get("name") == name, f"Expected name '{name}', got '{info.get('name')}'"
        if version:
            assert info.get("version") == version, f"Expected version '{version}', got '{info.get('version')}'"
        if capabilities:
            actual_caps = set(info.get("capabilities", []))
            expected_caps = set(capabilities)
            assert actual_caps >= expected_caps, \
                f"Missing capabilities: {expected_caps - actual_caps}"
    
    def assert_hook_success(self, result: Dict):
        """Assert hook returned success"""
        assert result.get("success") == True, \
            f"Hook failed: {result.get('logs', [])}"
    
    def assert_hook_logs_contain(self, result: Dict, *patterns: str):
        """Assert hook logs contain patterns"""
        logs = "\n".join(result.get("logs", []))
        for pattern in patterns:
            assert pattern in logs, \
                f"Pattern '{pattern}' not found in logs:\n{logs}"

class PluginTestError(Exception):
    """Plugin test error"""
    pass

class MockPlugin:
    """Mock plugin for testing Builder integration"""
    
    def __init__(self, name: str = "mock", version: str = "1.0.0"):
        self.name = name
        self.version = version
        self.capabilities = ["build.pre_hook", "build.post_hook"]
        self.pre_hook_calls = []
        self.post_hook_calls = []
    
    def to_executable(self, path: str):
        """Generate a mock plugin executable"""
        script = f'''#!/usr/bin/env python3
import json
import sys

PLUGIN_INFO = {{
    "name": "{self.name}",
    "version": "{self.version}",
    "author": "Mock",
    "description": "Mock plugin for testing",
    "homepage": "https://example.com",
    "capabilities": {json.dumps(self.capabilities)},
    "minBuilderVersion": "1.0.0",
    "license": "MIT"
}}

def handle_request(request):
    method = request.get("method")
    req_id = request.get("id", 1)
    
    if method == "plugin.info":
        return {{"jsonrpc": "2.0", "id": req_id, "result": PLUGIN_INFO}}
    elif method == "build.pre_hook":
        return {{
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {{
                "success": True,
                "logs": ["Mock pre-hook executed"]
            }}
        }}
    elif method == "build.post_hook":
        return {{
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {{
                "success": True,
                "logs": ["Mock post-hook executed"]
            }}
        }}
    else:
        return {{
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {{"code": -32601, "message": "Method not found"}}
        }}

for line in sys.stdin:
    request = json.loads(line)
    response = handle_request(request)
    print(json.dumps(response))
'''
        
        with open(path, 'w') as f:
            f.write(script)
        
        import os
        os.chmod(path, 0o755)

# Convenience functions
def quick_test(plugin_path: str) -> bool:
    """Quick smoke test of a plugin"""
    try:
        tester = PluginTester(plugin_path)
        
        # Test info
        info = tester.test_info()
        print(f"✓ Plugin info: {info['name']} v{info['version']}")
        
        # Test pre-hook if available
        if "build.pre_hook" in info.get("capabilities", []):
            result = tester.test_pre_hook()
            tester.assert_hook_success(result)
            print(f"✓ Pre-hook: {len(result.get('logs', []))} log messages")
        
        # Test post-hook if available
        if "build.post_hook" in info.get("capabilities", []):
            result = tester.test_post_hook()
            tester.assert_hook_success(result)
            print(f"✓ Post-hook: {len(result.get('logs', []))} log messages")
        
        print("\n✓ All tests passed!")
        return True
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        return False

