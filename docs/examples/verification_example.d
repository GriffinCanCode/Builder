/// Example: Formal Verification of Build Correctness
/// 
/// This example demonstrates how to use Builder's formal verification system
/// to prove build correctness and generate cryptographic proof certificates.

module examples.verification_example;

import std.stdio;
import engine.graph;
import engine.graph.verification;
import infrastructure.config.schema.schema;

void main()
{
    writeln("=== Build Correctness Verification Example ===\n");
    
    // Example 1: Simple verification
    example1_simpleVerification();
    
    // Example 2: Certificate generation
    example2_certificateGeneration();
    
    // Example 3: Handling verification failures
    example3_verificationFailures();
    
    // Example 4: Large graph verification
    example4_largeGraphVerification();
    
    writeln("\n=== All Examples Completed ===");
}

/// Example 1: Simple verification of a small build graph
void example1_simpleVerification()
{
    writeln("Example 1: Simple Verification\n");
    
    // Create a simple build graph
    auto graph = new BuildGraph();
    
    // Add library target
    auto lib = TargetBuilder.create("mylib")
        .withType(TargetType.Library)
        .withSources(["src/lib.d", "src/utils.d"])
        .withOutputs(["lib/mylib.a"])
        .withCommand("dmd -lib -of=lib/mylib.a src/lib.d src/utils.d")
        .build();
    
    // Add executable target
    auto app = TargetBuilder.create("myapp")
        .withType(TargetType.Executable)
        .withSources(["src/main.d"])
        .withOutputs(["bin/myapp"])
        .withCommand("dmd -of=bin/myapp src/main.d lib/mylib.a")
        .build();
    
    // Add test target
    auto test = TargetBuilder.create("test")
        .withType(TargetType.Test)
        .withSources(["test/test.d"])
        .withOutputs(["bin/test"])
        .withCommand("dmd -of=bin/test test/test.d lib/mylib.a")
        .build();
    
    graph.addTarget(lib);
    graph.addTarget(app);
    graph.addTarget(test);
    graph.addDependency("myapp", "mylib");
    graph.addDependency("test", "mylib");
    
    // Verify the graph
    writeln("Verifying build graph...");
    auto result = BuildVerifier.verify(graph);
    
    if (result.isOk)
    {
        auto proof = result.unwrap();
        
        writeln("✓ Build is provably correct!\n");
        writeln("Proof Details:");
        writeln("  Acyclicity: ", proof.acyclicity.isValid ? "✓" : "✗");
        writeln("    - Topological order: ", proof.acyclicity.topoOrder);
        writeln("    - Uniqueness: ", proof.acyclicity.uniqueness);
        writeln("    - Forward edges: ", proof.acyclicity.forwardEdges);
        
        writeln("\n  Hermeticity: ", proof.hermeticity.isValid ? "✓" : "✗");
        writeln("    - I ∩ O = ∅: ", proof.hermeticity.disjoint);
        writeln("    - Network isolated: ", proof.hermeticity.isolated);
        writeln("    - Hermetic targets: ", proof.hermeticity.hermeticTargets.length);
        
        writeln("\n  Determinism: ", proof.determinism.isValid ? "✓" : "✗");
        writeln("    - Complete specs: ", proof.determinism.complete);
        writeln("    - Targets with specs: ", proof.determinism.specs.length);
        
        writeln("\n  Race-Freedom: ", proof.raceFreedom.isValid ? "✓" : "✗");
        writeln("    - Properly ordered: ", proof.raceFreedom.properlyOrdered);
        writeln("    - Atomic access: ", proof.raceFreedom.atomicAccess);
        writeln("    - Disjoint writes: ", proof.raceFreedom.disjointWrites);
        writeln("    - Happens-before edges: ", proof.raceFreedom.happensBefore.length);
        
        writeln("\n  Proof Hash: ", proof.proofHash[0 .. 16], "...");
        writeln("  Timestamp: ", proof.timestamp);
    }
    else
    {
        writeln("✗ Verification failed: ", result.unwrapErr());
    }
    
    writeln();
}

/// Example 2: Generate and verify proof certificate
void example2_certificateGeneration()
{
    writeln("Example 2: Certificate Generation\n");
    
    // Create a build graph
    auto graph = new BuildGraph();
    
    auto target = TargetBuilder.create("hello")
        .withType(TargetType.Executable)
        .withSources(["hello.d"])
        .withOutputs(["bin/hello"])
        .withCommand("dmd -of=bin/hello hello.d")
        .build();
    
    graph.addTarget(target);
    
    // Generate certificate
    writeln("Generating proof certificate...");
    auto certResult = generateCertificate(graph, "example-workspace");
    
    if (certResult.isOk)
    {
        auto cert = certResult.unwrap();
        
        writeln("✓ Certificate generated!\n");
        writeln(cert.toString());
        
        // Verify certificate
        writeln("\nVerifying certificate...");
        auto verifyResult = cert.verify();
        
        if (verifyResult.isOk && verifyResult.unwrap())
        {
            writeln("✓ Certificate is valid and authentic!");
        }
        else
        {
            writeln("✗ Certificate verification failed: ", verifyResult.unwrapErr());
        }
        
        // In practice, you would save the certificate:
        // std.file.write("build-proof.cert", cert.toString());
    }
    else
    {
        writeln("✗ Certificate generation failed: ", certResult.unwrapErr());
    }
    
    writeln();
}

/// Example 3: Handling verification failures
void example3_verificationFailures()
{
    writeln("Example 3: Verification Failures\n");
    
    // Create a graph with a cycle (deferred validation)
    auto graph = new BuildGraph(ValidationMode.Deferred);
    
    auto a = TargetBuilder.create("a")
        .withType(TargetType.Library)
        .withSources(["a.d"])
        .withOutputs(["lib/a.a"])
        .build();
    
    auto b = TargetBuilder.create("b")
        .withType(TargetType.Library)
        .withSources(["b.d"])
        .withOutputs(["lib/b.a"])
        .build();
    
    auto c = TargetBuilder.create("c")
        .withType(TargetType.Library)
        .withSources(["c.d"])
        .withOutputs(["lib/c.a"])
        .build();
    
    graph.addTarget(a);
    graph.addTarget(b);
    graph.addTarget(c);
    
    // Create cycle: a -> b -> c -> a
    graph.addDependencyById(b.id, a.id);
    graph.addDependencyById(c.id, b.id);
    graph.addDependencyById(a.id, c.id);  // Creates cycle!
    
    writeln("Verifying graph with cycle...");
    auto result = BuildVerifier.verify(graph);
    
    if (result.isErr)
    {
        writeln("✗ Verification failed (as expected):");
        writeln("  Error: ", result.unwrapErr());
        writeln("\nThis demonstrates that the verifier correctly detects cycles!");
    }
    else
    {
        writeln("✗ Unexpected: verification succeeded despite cycle");
    }
    
    writeln();
}

/// Example 4: Large graph verification performance
void example4_largeGraphVerification()
{
    writeln("Example 4: Large Graph Verification\n");
    
    import std.datetime.stopwatch : StopWatch, AutoStart;
    import std.conv : to;
    
    // Create a large graph (binary tree structure)
    auto graph = new BuildGraph();
    
    writeln("Building large graph (200 nodes)...");
    foreach (i; 0 .. 200)
    {
        auto target = TargetBuilder.create("lib" ~ i.to!string)
            .withType(TargetType.Library)
            .withSources(["src/lib" ~ i.to!string ~ ".d"])
            .withOutputs(["lib/lib" ~ i.to!string ~ ".a"])
            .withCommand("dmd -lib -of=lib/lib" ~ i.to!string ~ ".a src/lib" ~ i.to!string ~ ".d")
            .build();
        
        graph.addTarget(target);
        
        // Add dependency to parent (binary tree)
        if (i > 0)
        {
            auto parentIdx = (i - 1) / 2;
            graph.addDependency("lib" ~ i.to!string, "lib" ~ parentIdx.to!string);
        }
    }
    
    writeln("Graph constructed with ", graph.nodes.length, " nodes");
    
    // Measure verification time
    writeln("\nVerifying graph...");
    auto sw = StopWatch(AutoStart.yes);
    auto result = BuildVerifier.verify(graph);
    sw.stop();
    
    if (result.isOk)
    {
        auto proof = result.unwrap();
        auto elapsed = sw.peek().total!"msecs";
        
        writeln("✓ Verification completed in ", elapsed, "ms");
        writeln("\nPerformance Metrics:");
        writeln("  Nodes verified: ", graph.nodes.length);
        writeln("  Edges verified: ", proof.raceFreedom.happensBefore.length);
        writeln("  Time per node: ", cast(double)elapsed / graph.nodes.length, "ms");
        
        writeln("\nProof Summary:");
        writeln("  Acyclicity: ", proof.acyclicity.topoOrder.length, " nodes in order");
        writeln("  Hermeticity: ", proof.hermeticity.hermeticTargets.length, " hermetic targets");
        writeln("  Determinism: ", proof.determinism.specs.length, " deterministic specs");
        writeln("  Race-freedom: ", proof.raceFreedom.happensBefore.length, " ordering constraints");
        
        if (elapsed < 200)
        {
            writeln("\n  Performance: EXCELLENT (< 200ms)");
        }
        else if (elapsed < 500)
        {
            writeln("\n  Performance: GOOD (< 500ms)");
        }
        else
        {
            writeln("\n  Performance: ACCEPTABLE (< 1s)");
        }
    }
    else
    {
        writeln("✗ Verification failed: ", result.unwrapErr());
    }
    
    writeln();
}

/// Bonus: Demonstrate determinism proof details
void exampleBonus_determinismDetails()
{
    writeln("Bonus: Determinism Proof Details\n");
    
    auto graph = new BuildGraph();
    
    auto target = TargetBuilder.create("example")
        .withType(TargetType.Executable)
        .withSources(["main.d", "utils.d"])
        .withOutputs(["bin/example"])
        .withCommand("dmd -O -release -of=bin/example main.d utils.d")
        .build();
    
    graph.addTarget(target);
    
    auto result = BuildVerifier.verify(graph);
    if (result.isOk)
    {
        auto proof = result.unwrap();
        auto spec = proof.determinism.specs["example"];
        
        writeln("Deterministic Specification for 'example':");
        writeln("  Inputs Hash: ", spec.inputsHash);
        writeln("  Command Hash: ", spec.commandHash);
        writeln("  Environment Hash: ", spec.envHash);
        writeln("\nThese hashes prove that:");
        writeln("  - Same source files + dependencies → same inputs hash");
        writeln("  - Same compiler command → same command hash");
        writeln("  - Same environment → same environment hash");
        writeln("  - Therefore: Same inputs → Same outputs (provably!)");
    }
    
    writeln();
}

