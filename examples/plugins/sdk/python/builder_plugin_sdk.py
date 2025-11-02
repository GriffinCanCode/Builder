"""
Builder Plugin SDK for Python

Simplifies creating Builder plugins by handling JSON-RPC boilerplate
and providing convenient decorators and helpers.

Example usage:
    from builder_plugin_sdk import Plugin, pre_hook, post_hook
    
    plugin = Plugin(
        name="myplugin",
        version="1.0.0",
        description="My awesome plugin"
    )
    
    @pre_hook
    def before_build(target, workspace):
        return {"success": True, "logs": ["Pre-build complete"]}
    
    @post_hook
    def after_build(target, workspace, outputs, success, duration_ms):
        return {"success": True, "logs": ["Post-build complete"]}
    
    if __name__ == "__main__":
        plugin.run()
"""

import json
import sys
from typing import Dict, List, Callable, Optional
from dataclasses import dataclass, asdict
from functools import wraps

__version__ = "1.0.0"

@dataclass
class PluginInfo:
    """Plugin metadata"""
    name: str
    version: str
    author: str = "Unknown"
    description: str = ""
    homepage: str = ""
    capabilities: List[str] = None
    minBuilderVersion: str = "1.0.0"
    license: str = "MIT"
    
    def __post_init__(self):
        if self.capabilities is None:
            self.capabilities = []

@dataclass
class Target:
    """Build target information"""
    name: str
    type: str
    language: str
    sources: List[str]
    deps: List[str]
    config: Dict
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'Target':
        return cls(
            name=data.get("name", ""),
            type=data.get("type", ""),
            language=data.get("language", ""),
            sources=data.get("sources", []),
            deps=data.get("deps", []),
            config=data.get("config", {})
        )

@dataclass
class Workspace:
    """Workspace information"""
    root: str
    cache_dir: str
    builder_version: str
    config: Dict
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'Workspace':
        return cls(
            root=data.get("root", "."),
            cache_dir=data.get("cache_dir", ".builder-cache"),
            builder_version=data.get("builder_version", "1.0.0"),
            config=data.get("config", {})
        )

class RPCError(Exception):
    """JSON-RPC error"""
    def __init__(self, code: int, message: str, data: Optional[Dict] = None):
        self.code = code
        self.message = message
        self.data = data
        super().__init__(message)

class Plugin:
    """Main plugin class"""
    
    def __init__(
        self,
        name: str,
        version: str,
        author: str = "Unknown",
        description: str = "",
        homepage: str = "",
        license: str = "MIT",
        minBuilderVersion: str = "1.0.0"
    ):
        self.info = PluginInfo(
            name=name,
            version=version,
            author=author,
            description=description,
            homepage=homepage,
            license=license,
            minBuilderVersion=minBuilderVersion
        )
        self.handlers: Dict[str, Callable] = {}
    
    def register(self, method: str, handler: Callable):
        """Register a method handler"""
        self.handlers[method] = handler
        
        # Auto-add capability based on method
        if method.startswith("build.") and method not in self.info.capabilities:
            self.info.capabilities.append(method)
    
    def handle_request(self, request: Dict) -> Dict:
        """Handle a JSON-RPC request"""
        try:
            method = request.get("method")
            req_id = request.get("id", 0)
            params = request.get("params", {})
            
            if method == "plugin.info":
                return self._success_response(req_id, asdict(self.info))
            
            if method not in self.handlers:
                return self._error_response(
                    req_id,
                    -32601,
                    f"Method not found: {method}"
                )
            
            # Call handler
            result = self.handlers[method](params)
            return self._success_response(req_id, result)
            
        except RPCError as e:
            return self._error_response(req_id, e.code, e.message, e.data)
        except Exception as e:
            return self._error_response(
                req_id,
                -32603,
                f"Internal error: {str(e)}"
            )
    
    def run(self):
        """Run the plugin (read from stdin, write to stdout)"""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            
            try:
                request = json.loads(line)
                response = self.handle_request(request)
                print(json.dumps(response), flush=True)
            except json.JSONDecodeError as e:
                error_resp = self._error_response(0, -32700, f"Parse error: {str(e)}")
                print(json.dumps(error_resp), flush=True)
    
    def _success_response(self, req_id: int, result) -> Dict:
        """Create success response"""
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": result
        }
    
    def _error_response(
        self,
        req_id: int,
        code: int,
        message: str,
        data: Optional[Dict] = None
    ) -> Dict:
        """Create error response"""
        error = {"code": code, "message": message}
        if data:
            error["data"] = data
        
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": error
        }

# Decorator for pre-hook
def pre_hook(func: Callable) -> Callable:
    """Decorator for pre-build hooks"""
    @wraps(func)
    def wrapper(params: Dict) -> Dict:
        target = Target.from_dict(params.get("target", {}))
        workspace = Workspace.from_dict(params.get("workspace", {}))
        return func(target, workspace)
    
    wrapper._method = "build.pre_hook"
    return wrapper

# Decorator for post-hook
def post_hook(func: Callable) -> Callable:
    """Decorator for post-build hooks"""
    @wraps(func)
    def wrapper(params: Dict) -> Dict:
        target = Target.from_dict(params.get("target", {}))
        workspace = Workspace.from_dict(params.get("workspace", {}))
        outputs = params.get("outputs", [])
        success = params.get("success", False)
        duration_ms = params.get("duration_ms", 0)
        return func(target, workspace, outputs, success, duration_ms)
    
    wrapper._method = "build.post_hook"
    return wrapper

# Decorator for artifact processing
def artifact_processor(func: Callable) -> Callable:
    """Decorator for artifact processing"""
    @wraps(func)
    def wrapper(params: Dict) -> Dict:
        artifacts = params.get("artifacts", [])
        config = params.get("config", {})
        return func(artifacts, config)
    
    wrapper._method = "artifact.process"
    return wrapper

def create_plugin_from_decorators(
    name: str,
    version: str,
    **kwargs
) -> Plugin:
    """Create plugin and auto-register decorated functions"""
    import inspect
    
    plugin = Plugin(name, version, **kwargs)
    
    # Find all decorated functions in caller's module
    frame = inspect.currentframe().f_back
    for obj in frame.f_globals.values():
        if callable(obj) and hasattr(obj, '_method'):
            plugin.register(obj._method, obj)
    
    return plugin

# Helper functions
def log(*messages: str) -> List[str]:
    """Create log messages"""
    return list(messages)

def success(logs: List[str], **kwargs) -> Dict:
    """Create success result"""
    result = {"success": True, "logs": logs}
    result.update(kwargs)
    return result

def failure(logs: List[str], **kwargs) -> Dict:
    """Create failure result"""
    result = {"success": False, "logs": logs}
    result.update(kwargs)
    return result

