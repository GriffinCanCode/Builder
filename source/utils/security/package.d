module utils.security;

/// Security utilities package
/// 
/// Provides security validation and sanitization for:
/// - File paths (command injection prevention)
/// - Command arguments (shell metacharacter detection)
/// - Path traversal attack prevention
///
/// Usage:
///   import utils.security;
///   
///   // Validate a path before using with external commands
///   if (SecurityValidator.isPathSafe(path))
///   {
///       auto result = execute(["chmod", "+x", path]);
///   }
///   
///   // Validate multiple paths
///   if (SecurityValidator.arePathsSafe(sources))
///   {
///       // Safe to proceed
///   }

public import utils.security.validation;

