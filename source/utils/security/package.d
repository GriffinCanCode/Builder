module utils.security;

/// Security utilities package
/// 
/// Comprehensive security framework for Builder:
/// - Command execution with injection prevention (SecureExecutor)
/// - Drop-in secure execute() replacement with automatic validation
/// - Cache integrity validation with BLAKE3 HMAC (IntegrityValidator)
/// - TOCTOU-resistant temporary directories (AtomicTempDir)
/// - Path and argument validation (SecurityValidator)
///
/// Quick Start:
///   import utils.security;
///   
///   // Option 1: Drop-in replacement for std.process.execute
///   auto res = execute(["ls", "-la"]);  // Automatically validated
///   
///   // Option 2: Builder pattern for advanced control
///   auto result = SecureExecutor.create()
///       .in_("/workspace")
///       .audit()
///       .runChecked(["ruby", "--version"]);
///   
///   // Atomic temp directory
///   auto tmp = AtomicTempDir.create("build-tmp");
///   
///   // Path validation
///   if (SecurityValidator.isPathSafe(userInput)) {
///       // Safe to use
///   }
///   
///   // Cache integrity
///   auto validator = IntegrityValidator.create();
///   auto signature = validator.sign(data);
///
/// Migration Guide:
///   Replace this:
///     import std.process : execute;
///   With this:
///     import utils.security : execute;  // Secure drop-in replacement

public import utils.security.validation;
public import utils.security.executor : SecureExecutor, ProcessResult, SecurityError, SecurityCode, execute;
public import utils.security.integrity;
public import utils.security.tempdir;

