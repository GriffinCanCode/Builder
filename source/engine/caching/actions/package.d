module engine.caching.actions;

/// Action-level caching for fine-grained incremental builds
/// 
/// This module provides action-level caching that operates at a finer
/// granularity than target-level caching. Each build action (compile, link,
/// codegen, etc.) can be cached and reused independently.
/// 
/// Key Features:
/// - Individual action caching (compile, link, codegen, test, etc.)
/// - Per-action input/output tracking
/// - Execution metadata tracking (flags, environment, etc.)
/// - Success/failure tracking for partial rebuilds
/// - SIMD-accelerated hash validation
/// - Binary serialization for fast I/O
/// 
/// Usage:
/// ```d
/// auto cache = new ActionCache(".builder-cache/actions");
/// 
/// auto actionId = ActionId("my-target", ActionType.Compile, inputHash, "file.d");
/// if (!cache.isCached(actionId, inputs, metadata)) {
///     // Perform compilation
///     cache.update(actionId, inputs, outputs, metadata, success);
/// }
/// ```

public import engine.caching.actions.action;
public import engine.caching.actions.storage;
public import engine.caching.actions.schema;

