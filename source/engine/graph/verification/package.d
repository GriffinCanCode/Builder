module engine.graph.verification;

/// Formal verification of build correctness
/// 
/// Provides mathematical proofs of critical build properties:
/// 
/// 1. **Acyclicity**: Graph is a DAG (no circular dependencies)
///    - Uses topological ordering as constructive proof
///    - Verifies each node appears exactly once
///    - Verifies all edges point forward in ordering
/// 
/// 2. **Hermeticity**: Input and output sets are disjoint (I ∩ O = ∅)
///    - Uses set-theoretic verification
///    - Verifies network isolation for hermetic builds
///    - Extends existing hermetic spec infrastructure
/// 
/// 3. **Determinism**: Same inputs produce same outputs
///    - Uses content-addressable hashing (BLAKE3)
///    - Generates deterministic specifications for each target
///    - Proves reproducibility mathematically
/// 
/// 4. **Race-Freedom**: No data races in parallel execution
///    - Uses happens-before relation analysis
///    - Verifies atomic operations for shared state
///    - Proves disjoint write sets
/// 
/// ## Usage
/// 
/// ```d
/// import engine.graph.verification;
/// 
/// // Verify build graph and generate proof
/// auto result = BuildVerifier.verify(graph);
/// if (result.isOk)
/// {
///     auto proof = result.unwrap();
///     writeln("Build is provably correct!");
///     writeln("Acyclicity: ", proof.acyclicity.isValid);
///     writeln("Hermeticity: ", proof.hermeticity.isValid);
///     writeln("Determinism: ", proof.determinism.isValid);
///     writeln("Race-freedom: ", proof.raceFreedom.isValid);
/// }
/// 
/// // Generate verifiable certificate
/// auto certResult = generateCertificate(graph, "my-workspace");
/// if (certResult.isOk)
/// {
///     auto cert = certResult.unwrap();
///     writeln(cert.toString());
///     
///     // Verify certificate
///     auto verifyResult = cert.verify();
///     assert(verifyResult.isOk);
/// }
/// ```
/// 
/// ## Innovation
/// 
/// This module provides formal correctness guarantees that are unique in build systems:
/// 
/// - **Mathematical Proofs**: Not just validation, but constructive proofs
/// - **Verifiable Certificates**: Cryptographically signed proof certificates
/// - **Set-Theoretic Foundation**: Builds on existing hermetic spec
/// - **Race-Freedom**: Formal verification of concurrent correctness
/// - **Content-Addressable**: Uses BLAKE3 for determinism proofs
/// 
/// ## Performance
/// 
/// - Acyclicity proof: O(V+E) topological sort
/// - Hermeticity proof: O(N²) pairwise disjointness check (N = paths)
/// - Determinism proof: O(V) hash computation per target
/// - Race-freedom proof: O(V+E) happens-before analysis
/// - Certificate generation: O(1) signing with BLAKE3
/// 
/// ## Thread Safety
/// 
/// All verification operations are thread-safe:
/// - Immutable proof structures
/// - No shared mutable state
/// - Atomic operations in underlying BuildGraph

public import engine.graph.verification.proof;

