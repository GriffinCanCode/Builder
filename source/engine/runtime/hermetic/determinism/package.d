module engine.runtime.hermetic.determinism;

/// Deterministic Builds Beyond Hermeticity
/// 
/// Extends hermetic builds with determinism enforcement to ensure
/// bit-for-bit reproducible outputs across builds. Goes beyond isolation
/// to control non-deterministic sources like timestamps, randomness,
/// and thread scheduling.
/// 
/// Key Features:
/// - Syscall interception for time(), random(), etc.
/// - Automatic detection of non-determinism sources
/// - Build output verification across runs
/// - Actionable repair suggestions with compiler flags
/// - Distributed build verification network (future)
/// 
/// Usage:
/// ```d
/// import engine.runtime.hermetic.determinism;
/// 
/// // Create hermetic executor
/// auto spec = HermeticSpecBuilder.forBuild(...);
/// auto executor = HermeticExecutor.create(spec.unwrap());
/// 
/// // Add determinism enforcement
/// auto config = DeterminismConfig.strict();
/// auto enforcer = DeterminismEnforcer.create(executor.unwrap(), config);
/// 
/// // Execute and verify
/// auto result = enforcer.unwrap().executeAndVerify(
///     ["gcc", "main.c", "-o", "main"],
///     "/workspace",
///     iterations: 3
/// );
/// 
/// if (!result.unwrap().deterministic) {
///     // Get repair suggestions
///     auto detections = NonDeterminismDetector.analyzeCompilerCommand(command);
///     auto plan = RepairEngine.generateRepairPlan(detections, result.violations);
///     writeln(plan);
/// }
/// ```
/// 
/// Architecture:
/// - `enforcer.d`: Main DeterminismEnforcer with syscall interception
/// - `detector.d`: Automatic detection of non-determinism sources
/// - `verifier.d`: Build output verification and comparison
/// - `repair.d`: Repair suggestions and actionable fixes
/// - `shim.c`: Syscall interception library (LD_PRELOAD)
/// 
/// Integration:
/// - Builds on top of HermeticExecutor (composition pattern)
/// - Integrates with ActionCache for tracking determinism
/// - Uses BLAKE3 hashing for fast verification
/// - Compatible with all language handlers

public import engine.runtime.hermetic.determinism.enforcer;
public import engine.runtime.hermetic.determinism.detector;
public import engine.runtime.hermetic.determinism.verifier;
public import engine.runtime.hermetic.determinism.repair;
public import engine.runtime.hermetic.determinism.integration;

