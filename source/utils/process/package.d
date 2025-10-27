module utils.process;

/// Process utilities package
/// Provides command availability checking and tool discovery
///
/// Architecture:
///   checker.d - Command/tool availability checking with caching
///
/// Usage:
///   import utils.process;
///   
///   // Check single command
///   if (isCommandAvailable("node")) { ... }
///   
///   // Use ToolChecker class for advanced features
///   if (ToolChecker.isAnyAvailable(["npm", "yarn", "pnpm"])) { ... }
///   string pm = ToolChecker.findFirstAvailable(["pnpm", "yarn", "npm"]);
///   string version = ToolChecker.getVersion("node");

public import utils.process.checker;

