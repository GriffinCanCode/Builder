module utils.security;

/// Security utilities package
/// 
/// Comprehensive security framework for Builder:
/// - Command execution with injection prevention (SecureExecutor)
/// - Cache integrity validation with BLAKE3 HMAC (IntegrityValidator)
/// - TOCTOU-resistant temporary directories (AtomicTempDir)
/// - Path and argument validation (SecurityValidator)
///
/// Quick Start:
///   import utils.security;
///   
///   // Safe command execution
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

public import utils.security.validation;
public import utils.security.executor;
public import utils.security.integrity;
public import utils.security.tempdir;

